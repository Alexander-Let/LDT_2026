package httpapi

import (
	"bytes"
	"crypto/rand"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strconv"
	"strings"
	"unicode/utf8"

	"github.com/gin-gonic/gin"

	"finni/internal/store"
)

const (
	maxDeviceTokenLen = 256
	minDeviceTokenLen = 16
	maxDisplayNameLen = 50

	maxStateBytes     = 256 << 10              // лимит на поле state
	maxStateBodyBytes = maxStateBytes + 16<<10 // запас на JSON-обёртку запроса

	// linkCodeAlphabet — однозначный алфавит: без 0/O/1/I.
	linkCodeAlphabet   = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	linkCodeLength     = 6
	linkCodeMaxRetries = 5
)

// newLinkCode генерирует код привязки из 6 символов. Длина алфавита (32)
// делит 256 нацело, поэтому смещения распределения нет.
func newLinkCode() (string, error) {
	buf := make([]byte, linkCodeLength)
	if _, err := rand.Read(buf); err != nil {
		return "", fmt.Errorf("generate link code: %w", err)
	}
	for i := range buf {
		buf[i] = linkCodeAlphabet[int(buf[i])%len(linkCodeAlphabet)]
	}
	return string(buf), nil
}

type createProfileRequest struct {
	DeviceToken string `json:"device_token"`
	DisplayName string `json:"display_name"`
}

// createProfile — POST /v1/profiles. Идемпотентен: если токен устройства уже
// зарегистрирован, возвращает существующий профиль с 200, иначе создаёт (201).
func (h *handler) createProfile(c *gin.Context) {
	var req createProfileRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		writeBadRequest(c, "тело запроса должно быть JSON с полями device_token и display_name")
		return
	}
	req.DisplayName = strings.TrimSpace(req.DisplayName)
	if l := len(req.DeviceToken); l < minDeviceTokenLen || l > maxDeviceTokenLen {
		writeBadRequest(c, fmt.Sprintf("device_token: длина от %d до %d символов", minDeviceTokenLen, maxDeviceTokenLen))
		return
	}
	if req.DisplayName == "" || utf8.RuneCountInString(req.DisplayName) > maxDisplayNameLen {
		writeBadRequest(c, fmt.Sprintf("display_name: от 1 до %d символов", maxDisplayNameLen))
		return
	}

	ctx := c.Request.Context()
	hash := sha256Hex(req.DeviceToken)

	profile, err := h.store.GetProfileByDeviceTokenHash(ctx, hash)
	if err == nil {
		c.JSON(http.StatusOK, profileIdentityResponse(profile))
		return
	}
	if !errors.Is(err, store.ErrNotFound) {
		writeInternalError(c, h.logger, err)
		return
	}

	for attempt := 0; attempt < linkCodeMaxRetries; attempt++ {
		code, err := newLinkCode()
		if err != nil {
			writeInternalError(c, h.logger, err)
			return
		}
		profile, err = h.store.CreateProfile(ctx, hash, req.DisplayName, code)
		if err == nil {
			c.JSON(http.StatusCreated, profileIdentityResponse(profile))
			return
		}
		var uniq *store.UniqueViolationError
		if errors.As(err, &uniq) && uniq.Constraint == "profiles_link_code_key" {
			continue // коллизия случайного кода — пробуем ещё раз
		}
		if errors.As(err, &uniq) {
			// Токен зарегистрирован параллельным запросом — отдаём существующий.
			profile, err = h.store.GetProfileByDeviceTokenHash(ctx, hash)
			if err == nil {
				c.JSON(http.StatusOK, profileIdentityResponse(profile))
				return
			}
		}
		writeInternalError(c, h.logger, err)
		return
	}
	writeInternalError(c, h.logger, errors.New("не удалось подобрать уникальный link_code"))
}

func profileIdentityResponse(p store.Profile) gin.H {
	return gin.H{
		"profile_id":   p.ID,
		"display_name": p.DisplayName,
		"link_code":    p.LinkCode,
		"created_at":   p.CreatedAt,
	}
}

// getMyProfile — GET /v1/profiles/me.
func (h *handler) getMyProfile(c *gin.Context) {
	p := profileFromContext(c)
	c.JSON(http.StatusOK, gin.H{
		"profile_id":    p.ID,
		"display_name":  p.DisplayName,
		"link_code":     p.LinkCode,
		"state_version": p.StateVersion,
		"updated_at":    p.UpdatedAt,
	})
}

// getMyState — GET /v1/profiles/me/state.
func (h *handler) getMyState(c *gin.Context) {
	p := profileFromContext(c)
	c.JSON(http.StatusOK, stateResponse(p))
}

type putStateRequest struct {
	State       json.RawMessage `json:"state"`
	BaseVersion *int            `json:"base_version"`
}

// putMyState — PUT /v1/profiles/me/state с оптимистичной блокировкой.
func (h *handler) putMyState(c *gin.Context) {
	p := profileFromContext(c)

	c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, maxStateBodyBytes)
	var req putStateRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		writeBadRequest(c, "тело запроса должно быть JSON с полями state и base_version")
		return
	}
	if req.BaseVersion == nil || *req.BaseVersion < 0 {
		writeBadRequest(c, "base_version: обязательное целое число >= 0")
		return
	}
	trimmed := bytes.TrimSpace(req.State)
	if len(trimmed) == 0 || trimmed[0] != '{' {
		writeBadRequest(c, "state: должен быть JSON-объектом")
		return
	}
	if len(req.State) > maxStateBytes {
		writeBadRequest(c, "state: размер не должен превышать 256 КБ")
		return
	}

	updated, err := h.store.UpdateProfileState(c.Request.Context(), p.ID, *req.BaseVersion, req.State)
	switch {
	case err == nil:
		c.JSON(http.StatusOK, stateResponse(updated))
	case errors.Is(err, store.ErrVersionConflict):
		c.JSON(http.StatusConflict, gin.H{
			"error":           errorBody{Code: "version_conflict", Message: "версия состояния устарела, используйте current_version"},
			"current_version": updated.StateVersion,
			"current_state":   json.RawMessage(updated.State),
		})
	case errors.Is(err, store.ErrNotFound):
		writeNotFound(c, "профиль не найден")
	default:
		writeInternalError(c, h.logger, err)
	}
}

func stateResponse(p store.Profile) gin.H {
	state := json.RawMessage(p.State)
	if len(state) == 0 {
		state = json.RawMessage(`{}`)
	}
	return gin.H{
		"state":         state,
		"state_version": p.StateVersion,
		"updated_at":    p.UpdatedAt,
	}
}

// listMyBonuses — GET /v1/profiles/me/bonuses: ещё не применённые бонусы.
func (h *handler) listMyBonuses(c *gin.Context) {
	p := profileFromContext(c)
	bonuses, err := h.store.ListPendingBonuses(c.Request.Context(), p.ID)
	if err != nil {
		writeInternalError(c, h.logger, err)
		return
	}
	items := make([]gin.H, 0, len(bonuses))
	for _, b := range bonuses {
		items = append(items, gin.H{
			"id":         b.ID,
			"amount":     b.Amount,
			"reason":     b.Reason,
			"created_at": b.CreatedAt,
		})
	}
	c.JSON(http.StatusOK, items)
}

// applyMyBonus — POST /v1/profiles/me/bonuses/:id/applied. Идемпотентен.
func (h *handler) applyMyBonus(c *gin.Context) {
	p := profileFromContext(c)
	bonusID, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil || bonusID <= 0 {
		writeBadRequest(c, "id бонуса должен быть положительным целым числом")
		return
	}
	bonus, err := h.store.MarkBonusApplied(c.Request.Context(), p.ID, bonusID)
	switch {
	case err == nil:
		c.JSON(http.StatusOK, bonusResponse(bonus))
	case errors.Is(err, store.ErrNotFound):
		writeNotFound(c, "бонус не найден")
	default:
		writeInternalError(c, h.logger, err)
	}
}

func bonusResponse(b store.Bonus) gin.H {
	resp := gin.H{
		"bonus_id":   b.ID,
		"amount":     b.Amount,
		"reason":     b.Reason,
		"created_at": b.CreatedAt,
	}
	if b.AppliedAt != nil {
		resp["applied_at"] = *b.AppliedAt
	} else {
		resp["applied_at"] = nil
	}
	return resp
}
