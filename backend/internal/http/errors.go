package httpapi

import (
	"log/slog"
	"net/http"

	"github.com/gin-gonic/gin"
)

// errorBody — единый формат ошибки API: {"error": {"code": "...", "message": "..."}}.
type errorBody struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}

func writeError(c *gin.Context, status int, code, message string) {
	c.AbortWithStatusJSON(status, gin.H{"error": errorBody{Code: code, Message: message}})
}

func writeBadRequest(c *gin.Context, message string) {
	writeError(c, http.StatusBadRequest, "invalid_request", message)
}

func writeUnauthorized(c *gin.Context, message string) {
	writeError(c, http.StatusUnauthorized, "unauthorized", message)
}

func writeNotFound(c *gin.Context, message string) {
	writeError(c, http.StatusNotFound, "not_found", message)
}

func writeInternalError(c *gin.Context, logger *slog.Logger, err error) {
	logger.Error("internal error",
		"method", c.Request.Method,
		"path", c.Request.URL.Path,
		"error", err,
	)
	writeError(c, http.StatusInternalServerError, "internal", "внутренняя ошибка сервера")
}
