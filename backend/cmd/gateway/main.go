package main

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"os/signal"
	"syscall"
	"time"
)

// Gateway — тонкий reverse proxy перед доменными сервисами (только stdlib).
// Маршрутизация по префиксу пути:
//
//	/v1/parents/ → parents (PARENTS_URL)
//	/v1/content/ → content (CONTENT_URL)
//	остальное    → profiles (PROFILES_URL): /v1/profiles*, /healthz, /readyz
func main() {
	logger := newLogger(envOr("LOG_LEVEL", "info"))
	slog.SetDefault(logger)

	profiles, err := newUpstream(envOr("PROFILES_URL", "http://localhost:8081"), logger)
	if err != nil {
		logger.Error("profiles upstream", "error", err)
		os.Exit(1)
	}
	content, err := newUpstream(envOr("CONTENT_URL", "http://localhost:8082"), logger)
	if err != nil {
		logger.Error("content upstream", "error", err)
		os.Exit(1)
	}
	parents, err := newUpstream(envOr("PARENTS_URL", "http://localhost:8083"), logger)
	if err != nil {
		logger.Error("parents upstream", "error", err)
		os.Exit(1)
	}

	mux := http.NewServeMux()
	mux.Handle("/v1/parents/", parents)
	mux.Handle("/v1/content/", content)
	mux.Handle("/", profiles)

	addr := envOr("HTTP_ADDR", ":8080")
	srv := &http.Server{
		Addr:              addr,
		Handler:           requestLogger(mux, logger),
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      10 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	go func() {
		logger.Info("gateway listening", "addr", addr)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			logger.Error("server failed", "error", err)
			os.Exit(1)
		}
	}()

	<-ctx.Done()
	logger.Info("shutting down")

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := srv.Shutdown(shutdownCtx); err != nil {
		logger.Error("graceful shutdown failed", "error", err)
		os.Exit(1)
	}
}

// newUpstream строит reverse proxy на один апстрим; путь и заголовки запроса
// сохраняются (NewSingleHostReverseProxy сам проставляет X-Forwarded-For).
func newUpstream(target string, logger *slog.Logger) (*httputil.ReverseProxy, error) {
	u, err := url.Parse(target)
	if err != nil {
		return nil, fmt.Errorf("parse upstream url %q: %w", target, err)
	}
	proxy := httputil.NewSingleHostReverseProxy(u)
	proxy.ErrorHandler = func(w http.ResponseWriter, r *http.Request, err error) {
		logger.Error("upstream error", "target", target, "path", r.URL.Path, "error", err)
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadGateway)
		_, _ = w.Write([]byte(`{"error":{"code":"bad_gateway","message":"сервис временно недоступен"}}`))
	}
	return proxy, nil
}

func envOr(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

// requestLogger логирует запросы на границе. ResponseWriter не оборачивается,
// чтобы не ломать Flush/streaming у ReverseProxy.
func requestLogger(next http.Handler, logger *slog.Logger) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		next.ServeHTTP(w, r)
		logger.Info("http request",
			"method", r.Method,
			"path", r.URL.Path,
			"latency", time.Since(start).String(),
			"client_ip", r.RemoteAddr,
		)
	})
}

func newLogger(level string) *slog.Logger {
	var lvl slog.Level
	if err := lvl.UnmarshalText([]byte(level)); err != nil {
		lvl = slog.LevelInfo
	}
	return slog.New(slog.NewTextHandler(os.Stdout, &slog.HandlerOptions{Level: lvl}))
}
