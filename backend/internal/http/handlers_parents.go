package httpapi

import (
	"crypto/subtle"
	"errors"
	"net/http"
	"net/mail"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/gin-gonic/gin"

	"finni/internal/store"
)

const (
	otpTTL           = 10 * time.Minute
	parentSessionTTL = 30 * 24 * time.Hour

	maxBonusAmount    = 100
	maxBonusReasonLen = 200
)

type otpRequest struct {
	Email   string `json:"email"`
	Consent bool   `json:"consent"`
}

// requestParentOTP — POST /v1/parents/otp. Отправки почты нет: код пишется
// в лог, а при APP_ENV=dev дополнительно возвращается в поле dev_code.
func (h *handler) requestParentOTP(c *gin.Context) {
	var req otpRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		writeBadRequest(c, "тело запроса должно быть JSON с полями email и consent")
		return
	}
	req.Email = strings.TrimSpace(req.Email)
	if !validEmail(req.Email) {
		writeBadRequest(c, "email: некорректный адрес")
		return
	}
	if !req.Consent {
		writeBadRequest(c, "consent: требуется согласие на обработку персональных данных")
		return
	}

	ctx := c.Request.Context()
	if _, err := h.store.GetOrCreateParent(ctx, req.Email); err != nil {
		writeInternalError(c, h.logger, err)
		return
	}

	code, err := newOTPCode()
	if err != nil {
		writeInternalError(c, h.logger, err)
		return
	}
	expiresAt := time.Now().Add(otpTTL)
	if err := h.store.UpsertParentOTP(ctx, req.Email, sha256Hex(code), expiresAt); err != nil {
		writeInternalError(c, h.logger, err)
		return
	}

	// Отправки email нет: код доступен в логе сервера.
	h.logger.Info("parent otp issued", "email", req.Email, "code", code)

	resp := gin.H{"expires_at": expiresAt}
	if h.appEnv == "dev" {
		resp["dev_code"] = code
	}
	c.JSON(http.StatusOK, resp)
}

func validEmail(email string) bool {
	if email == "" || len(email) > 254 {
		return false
	}
	addr, err := mail.ParseAddress(email)
	if err != nil || addr.Address != email {
		return false
	}
	at := strings.LastIndex(email, "@")
	return at > 0 && strings.Contains(email[at+1:], ".")
}

type sessionRequest struct {
	Email string `json:"email"`
	Code  string `json:"code"`
}

// createParentSession — POST /v1/parents/session: обмен одноразового кода
// на токен родительской сессии (TTL 30 дней).
func (h *handler) createParentSession(c *gin.Context) {
	var req sessionRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		writeBadRequest(c, "тело запроса должно быть JSON с полями email и code")
		return
	}
	req.Email = strings.TrimSpace(req.Email)
	req.Code = strings.TrimSpace(req.Code)
	if !validEmail(req.Email) || len(req.Code) != 6 {
		writeBadRequest(c, "укажите email и 6-значный code")
		return
	}

	ctx := c.Request.Context()
	otp, err := h.store.GetParentOTP(ctx, req.Email)
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			writeUnauthorized(c, "неверный код или email")
			return
		}
		writeInternalError(c, h.logger, err)
		return
	}
	if time.Now().After(otp.ExpiresAt) {
		writeUnauthorized(c, "код истёк, запросите новый")
		return
	}
	codeHash := sha256Hex(req.Code)
	if subtle.ConstantTimeCompare([]byte(codeHash), []byte(otp.CodeHash)) != 1 {
		writeUnauthorized(c, "неверный код или email")
		return
	}

	parent, err := h.store.GetParentByEmail(ctx, req.Email)
	if err != nil {
		writeInternalError(c, h.logger, err)
		return
	}

	token, err := newSessionToken()
	if err != nil {
		writeInternalError(c, h.logger, err)
		return
	}
	expiresAt := time.Now().Add(parentSessionTTL)
	if err := h.store.CreateParentSession(ctx, parent.ID, sha256Hex(token), expiresAt); err != nil {
		writeInternalError(c, h.logger, err)
		return
	}
	if err := h.store.DeleteParentOTP(ctx, req.Email); err != nil {
		h.logger.Warn("failed to delete used otp", "email", req.Email, "error", err)
	}

	c.JSON(http.StatusCreated, gin.H{
		"parent_token": token,
		"expires_at":   expiresAt,
	})
}

type linkRequest struct {
	LinkCode string `json:"link_code"`
}

// createParentLink — POST /v1/parents/links: привязка профиля ребёнка
// по link_code. Идемпотентна.
func (h *handler) createParentLink(c *gin.Context) {
	parent := parentFromContext(c)

	var req linkRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		writeBadRequest(c, "тело запроса должно быть JSON с полем link_code")
		return
	}
	req.LinkCode = strings.TrimSpace(req.LinkCode)
	if utf8.RuneCountInString(req.LinkCode) != linkCodeLength {
		writeBadRequest(c, "link_code: код из 6 символов")
		return
	}

	ctx := c.Request.Context()
	profile, err := h.store.GetProfileByLinkCode(ctx, req.LinkCode)
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			writeNotFound(c, "профиль с таким кодом не найден")
			return
		}
		writeInternalError(c, h.logger, err)
		return
	}
	if err := h.store.LinkParentProfile(ctx, parent.ID, profile.ID); err != nil {
		writeInternalError(c, h.logger, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"profile_id":   profile.ID,
		"display_name": profile.DisplayName,
	})
}

// listChildren — GET /v1/parents/children.
func (h *handler) listChildren(c *gin.Context) {
	parent := parentFromContext(c)
	children, err := h.store.ListLinkedChildren(c.Request.Context(), parent.ID)
	if err != nil {
		writeInternalError(c, h.logger, err)
		return
	}
	items := make([]gin.H, 0, len(children))
	for _, ch := range children {
		items = append(items, gin.H{
			"profile_id":    ch.ProfileID,
			"display_name":  ch.DisplayName,
			"linked_at":     ch.LinkedAt,
			"state_version": ch.StateVersion,
			"updated_at":    ch.UpdatedAt,
		})
	}
	c.JSON(http.StatusOK, items)
}

// linkedChildProfile возвращает профиль, только если он привязан к родителю.
// При отсутствии привязки отвечает 404 (не раскрываем существование профиля).
func (h *handler) linkedChildProfile(c *gin.Context, parentID string) (store.Profile, bool) {
	profileID := c.Param("profile_id")
	if !isUUID(profileID) {
		writeBadRequest(c, "profile_id должен быть uuid")
		return store.Profile{}, false
	}
	ctx := c.Request.Context()
	linked, err := h.store.IsParentLinked(ctx, parentID, profileID)
	if err != nil {
		writeInternalError(c, h.logger, err)
		return store.Profile{}, false
	}
	if !linked {
		writeNotFound(c, "профиль не привязан к этому родителю")
		return store.Profile{}, false
	}
	profile, err := h.store.GetProfileByID(ctx, profileID)
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			writeNotFound(c, "профиль не найден")
			return store.Profile{}, false
		}
		writeInternalError(c, h.logger, err)
		return store.Profile{}, false
	}
	return profile, true
}

// getChildSummary — GET /v1/parents/children/:profile_id/summary.
// state непрозрачен для сервера — его рендерит клиент.
func (h *handler) getChildSummary(c *gin.Context) {
	parent := parentFromContext(c)
	profile, ok := h.linkedChildProfile(c, parent.ID)
	if !ok {
		return
	}
	resp := stateResponse(profile)
	resp["profile_id"] = profile.ID
	resp["display_name"] = profile.DisplayName
	c.JSON(http.StatusOK, resp)
}

type createBonusRequest struct {
	Amount int    `json:"amount"`
	Reason string `json:"reason"`
}

// createChildBonus — POST /v1/parents/children/:profile_id/bonuses.
func (h *handler) createChildBonus(c *gin.Context) {
	parent := parentFromContext(c)

	var req createBonusRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		writeBadRequest(c, "тело запроса должно быть JSON с полями amount и reason")
		return
	}
	if req.Amount < 1 || req.Amount > maxBonusAmount {
		writeBadRequest(c, "amount: целое число от 1 до 100")
		return
	}
	req.Reason = strings.TrimSpace(req.Reason)
	if utf8.RuneCountInString(req.Reason) > maxBonusReasonLen {
		writeBadRequest(c, "reason: не более 200 символов")
		return
	}

	profile, ok := h.linkedChildProfile(c, parent.ID)
	if !ok {
		return
	}
	bonus, err := h.store.CreateBonus(c.Request.Context(), profile.ID, req.Amount, req.Reason)
	if err != nil {
		writeInternalError(c, h.logger, err)
		return
	}
	c.JSON(http.StatusCreated, gin.H{
		"bonus_id":   bonus.ID,
		"profile_id": bonus.ProfileID,
		"amount":     bonus.Amount,
		"reason":     bonus.Reason,
		"created_at": bonus.CreatedAt,
	})
}
