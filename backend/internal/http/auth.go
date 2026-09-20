package httpapi

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"errors"
	"fmt"
	"math/big"
	"strings"

	"github.com/gin-gonic/gin"

	"finni/internal/store"
)

const (
	ctxProfileKey = "finni.profile"
	ctxParentKey  = "finni.parent"
)

// sha256Hex — единственное, что сервер хранит от токенов и кодов.
func sha256Hex(s string) string {
	sum := sha256.Sum256([]byte(s))
	return hex.EncodeToString(sum[:])
}

func bearerToken(c *gin.Context) (string, bool) {
	header := c.GetHeader("Authorization")
	token, ok := strings.CutPrefix(header, "Bearer ")
	if !ok {
		return "", false
	}
	token = strings.TrimSpace(token)
	return token, token != ""
}

func newSessionToken() (string, error) {
	buf := make([]byte, 32)
	if _, err := rand.Read(buf); err != nil {
		return "", fmt.Errorf("generate session token: %w", err)
	}
	return base64.RawURLEncoding.EncodeToString(buf), nil
}

// newOTPCode генерирует 6-значный код (с ведущими нулями).
func newOTPCode() (string, error) {
	n, err := rand.Int(rand.Reader, big.NewInt(1_000_000))
	if err != nil {
		return "", fmt.Errorf("generate otp code: %w", err)
	}
	return fmt.Sprintf("%06d", n.Int64()), nil
}

// childAuth аутентифицирует детский профиль по токену устройства:
// Authorization: Bearer <device_token>. В базе хранится только SHA-256-хэш.
func (h *handler) childAuth() gin.HandlerFunc {
	return func(c *gin.Context) {
		token, ok := bearerToken(c)
		if !ok {
			writeUnauthorized(c, "требуется заголовок Authorization: Bearer <device_token>")
			return
		}
		profile, err := h.store.GetProfileByDeviceTokenHash(c.Request.Context(), sha256Hex(token))
		if err != nil {
			if errors.Is(err, store.ErrNotFound) {
				writeUnauthorized(c, "профиль не найден или токен неверный")
				return
			}
			writeInternalError(c, h.logger, err)
			return
		}
		c.Set(ctxProfileKey, profile)
		c.Next()
	}
}

// parentAuth аутентифицирует родителя по токену сессии из OTP-флоу:
// Authorization: Bearer <parent_token>. В базе — только хэш токена.
func (h *handler) parentAuth() gin.HandlerFunc {
	return func(c *gin.Context) {
		token, ok := bearerToken(c)
		if !ok {
			writeUnauthorized(c, "требуется заголовок Authorization: Bearer <parent_token>")
			return
		}
		parent, err := h.store.GetParentBySessionTokenHash(c.Request.Context(), sha256Hex(token))
		if err != nil {
			if errors.Is(err, store.ErrNotFound) {
				writeUnauthorized(c, "сессия не найдена или истекла")
				return
			}
			writeInternalError(c, h.logger, err)
			return
		}
		c.Set(ctxParentKey, parent)
		c.Next()
	}
}

func profileFromContext(c *gin.Context) store.Profile {
	return c.MustGet(ctxProfileKey).(store.Profile)
}

func parentFromContext(c *gin.Context) store.Parent {
	return c.MustGet(ctxParentKey).(store.Parent)
}

// isUUID проверяет формат uuid, чтобы невалидные path-параметры отсекать
// с 400, а не получать ошибку парсинга от PostgreSQL.
func isUUID(s string) bool {
	if len(s) != 36 {
		return false
	}
	for i := 0; i < len(s); i++ {
		switch i {
		case 8, 13, 18, 23:
			if s[i] != '-' {
				return false
			}
		default:
			ch := s[i]
			if !('0' <= ch && ch <= '9' || 'a' <= ch && ch <= 'f' || 'A' <= ch && ch <= 'F') {
				return false
			}
		}
	}
	return true
}
