package httpapi

import (
	"context"
	"log/slog"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"

	"finni/internal/store"
)

// Store — граница между HTTP-слоем и базой данных. Узкий интерфейс,
// чтобы хендлеры можно было тестировать без PostgreSQL.
type Store interface {
	Ping(ctx context.Context) error

	GetProfileByID(ctx context.Context, id string) (store.Profile, error)
	GetProfileByDeviceTokenHash(ctx context.Context, hash string) (store.Profile, error)
	GetProfileByLinkCode(ctx context.Context, code string) (store.Profile, error)
	CreateProfile(ctx context.Context, deviceTokenHash, displayName, linkCode string) (store.Profile, error)
	UpdateProfileState(ctx context.Context, id string, baseVersion int, state []byte) (store.Profile, error)

	LatestContentBundle(ctx context.Context) (store.ContentBundle, error)

	GetParentByEmail(ctx context.Context, email string) (store.Parent, error)
	GetOrCreateParent(ctx context.Context, email string) (store.Parent, error)
	UpsertParentOTP(ctx context.Context, email, codeHash string, expiresAt time.Time) error
	GetParentOTP(ctx context.Context, email string) (store.ParentOTP, error)
	DeleteParentOTP(ctx context.Context, email string) error
	CreateParentSession(ctx context.Context, parentID, tokenHash string, expiresAt time.Time) error
	GetParentBySessionTokenHash(ctx context.Context, tokenHash string) (store.Parent, error)
	LinkParentProfile(ctx context.Context, parentID, profileID string) error
	IsParentLinked(ctx context.Context, parentID, profileID string) (bool, error)
	ListLinkedChildren(ctx context.Context, parentID string) ([]store.LinkedChild, error)

	CreateBonus(ctx context.Context, profileID string, amount int, reason string) (store.Bonus, error)
	ListPendingBonuses(ctx context.Context, profileID string) ([]store.Bonus, error)
	MarkBonusApplied(ctx context.Context, profileID string, bonusID int64) (store.Bonus, error)
}

var _ Store = (*store.Store)(nil)

type handler struct {
	store  Store
	logger *slog.Logger
	appEnv string
}

func NewRouter(db Store, logger *slog.Logger, appEnv string) *gin.Engine {
	if appEnv == "prod" {
		gin.SetMode(gin.ReleaseMode)
	}

	h := &handler{store: db, logger: logger, appEnv: appEnv}

	r := gin.New()
	r.Use(gin.Recovery())
	r.Use(requestLogger(logger))

	r.GET("/healthz", healthz)
	r.GET("/readyz", readyz(db))

	v1 := r.Group("/v1")

	// Детский профиль: регистрация открытая, остальное — по токену устройства.
	v1.POST("/profiles", h.createProfile)

	child := v1.Group("", h.childAuth())
	child.GET("/profiles/me", h.getMyProfile)
	child.GET("/profiles/me/state", h.getMyState)
	child.PUT("/profiles/me/state", h.putMyState)
	child.GET("/profiles/me/bonuses", h.listMyBonuses)
	child.POST("/profiles/me/bonuses/:id/applied", h.applyMyBonus)
	child.GET("/content/bundle", h.getContentBundle)

	// Родитель: вход по одноразовому коду, остальное — по токену сессии.
	v1.POST("/parents/otp", h.requestParentOTP)
	v1.POST("/parents/session", h.createParentSession)

	parent := v1.Group("/parents", h.parentAuth())
	parent.POST("/links", h.createParentLink)
	parent.GET("/children", h.listChildren)
	parent.GET("/children/:profile_id/summary", h.getChildSummary)
	parent.POST("/children/:profile_id/bonuses", h.createChildBonus)

	return r
}

func healthz(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"status": "ok"})
}

func readyz(db Store) gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx, cancel := context.WithTimeout(c.Request.Context(), time.Second)
		defer cancel()
		if err := db.Ping(ctx); err != nil {
			c.JSON(http.StatusServiceUnavailable, gin.H{"status": "unavailable"})
			return
		}
		c.JSON(http.StatusOK, gin.H{"status": "ok"})
	}
}
