package httpapi

import (
	"encoding/json"
	"errors"
	"net/http"

	"github.com/gin-gonic/gin"

	"finni/internal/store"
)

// getContentBundle — GET /v1/content/bundle: последний опубликованный бандл.
// Клиент сам сравнивает version со своей локальной копией.
func (h *handler) getContentBundle(c *gin.Context) {
	bundle, err := h.store.LatestContentBundle(c.Request.Context())
	switch {
	case err == nil:
		c.JSON(http.StatusOK, gin.H{
			"version":      bundle.Version,
			"published_at": bundle.PublishedAt,
			"payload":      json.RawMessage(bundle.Payload),
		})
	case errors.Is(err, store.ErrNotFound):
		writeNotFound(c, "контент ещё не опубликован")
	default:
		writeInternalError(c, h.logger, err)
	}
}
