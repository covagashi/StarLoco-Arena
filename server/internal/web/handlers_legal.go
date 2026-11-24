package web

import (
	"net/http"
	"strings"
)

// The legal pages exist because this project runs a public service built on
// somebody else's intellectual property, and the honest way to do that is to
// say so on the site rather than only in a file on GitHub that no player reads.
//
// Three pages, all public and all crawlable:
//
//   - /legal   — non-affiliation, whose IP this is, and how a rights holder
//     gets material removed without needing a lawyer.
//   - /privacy — the GDPR notice. The portal is operated from the EU and holds
//     account records, so this is not optional.
//   - /terms   — what a player is agreeing to, and what gets them banned.
//
// They carry no state beyond the contact address, so they share one model.

// legalVersion and legalUpdated stamp the three documents.
//
// An undated policy cannot be relied on: neither the operator nor a player can
// later show which terms applied when. Both peers in this space and the GDPR's
// own transparency guidance treat a version + effective date as part of the
// document rather than decoration.
//
// Bump both together whenever the substance changes, not for a typo.
const (
	legalVersion = "1.1"
	legalUpdated = "2026-11-24"
)

// legalData backs all three static legal pages.
type legalData struct {
	*baseData
	// ContactEmail is the address a rights holder or a data subject writes to.
	// Empty renders a fallback line rather than a broken mailto:, because a
	// takedown page that cannot be contacted is worse than no page at all.
	ContactEmail string

	// Host is the hosting provider, named because French law (LCEN art. 6
	// III-2) lets a NON-PROFESSIONAL publisher stay anonymous to the public
	// only on condition that the host is identified and holds the publisher's
	// real identity. Without this the anonymity is not lawful, it is just
	// missing information.
	Host string

	// Version and Updated stamp the document.
	Version string
	Updated string
}

// newLegalData assembles the shared model for /legal, /privacy and /terms.
func (s *Server) newLegalData(w http.ResponseWriter, r *http.Request, titleKey, navKey string) *legalData {
	return &legalData{
		baseData:     s.newBase(w, r, s.tr(r, titleKey), navKey),
		ContactEmail: s.contactEmail(),
		Host:         strings.TrimSpace(s.cfg.HostingProvider),
		Version:      legalVersion,
		Updated:      legalUpdated,
	}
}

// contactEmail is the address shown on the legal and privacy pages.
func (s *Server) contactEmail() string {
	return strings.TrimSpace(s.cfg.ContactEmail)
}

func (s *Server) handleLegal(w http.ResponseWriter, r *http.Request) {
	s.render(w, http.StatusOK, "legal.html", s.newLegalData(w, r, "legal.title", "legal"))
}

func (s *Server) handlePrivacy(w http.ResponseWriter, r *http.Request) {
	s.render(w, http.StatusOK, "privacy.html", s.newLegalData(w, r, "privacy.title", "privacy"))
}

func (s *Server) handleTerms(w http.ResponseWriter, r *http.Request) {
	s.render(w, http.StatusOK, "terms.html", s.newLegalData(w, r, "terms.title", "terms"))
}
