package mailer

import (
	"fmt"
	"net"
	"net/smtp"
	"os"
	"strings"
	"time"
)

func Configured() bool {
	return strings.TrimSpace(os.Getenv("SMTP_USER")) != "" && smtpPassword() != ""
}

func smtpPassword() string {
	p := os.Getenv("SMTP_PASSWORD")
	if p == "" {
		p = os.Getenv("SMTP_PASS")
	}
	return strings.ReplaceAll(strings.TrimSpace(p), " ", "")
}

func getenv(key, fallback string) string {
	v := strings.TrimSpace(os.Getenv(key))
	if v == "" {
		return fallback
	}
	return v
}

func buildMessage(fromName, from, to, subject, body string) string {
	fromHeader := fmt.Sprintf("%s <%s>", fromName, from)
	return strings.Join([]string{
		"From: " + fromHeader,
		"To: " + to,
		"Subject: " + subject,
		"Date: " + time.Now().UTC().Format(time.RFC1123Z),
		"MIME-Version: 1.0",
		"Content-Type: text/plain; charset=UTF-8",
		"",
		body,
	}, "\r\n")
}

// Send delivers a plain-text email through SMTP.
// The authenticated Gmail account (SMTP_USER) is the sender only.
// [to] is the only recipient — the customer — never the SMTP login.
func Send(to, subject, body string) error {
	host := getenv("SMTP_HOST", "smtp.gmail.com")
	port := getenv("SMTP_PORT", "587")
	user := strings.TrimSpace(os.Getenv("SMTP_USER"))
	pass := smtpPassword()
	from := strings.TrimSpace(os.Getenv("SMTP_FROM"))
	if from == "" {
		from = user
	}
	fromName := getenv("SMTP_FROM_NAME", "Agraz")
	if user == "" || pass == "" {
		return fmt.Errorf("SMTP is not configured")
	}
	to = strings.TrimSpace(to)
	if to == "" {
		return fmt.Errorf("recipient is required")
	}

	msg := buildMessage(fromName, from, to, subject, body)
	addr := net.JoinHostPort(host, port)
	auth := smtp.PlainAuth("", user, pass, host)
	// Envelope sender must be the Gmail login. Recipients are only [to].
	return smtp.SendMail(addr, auth, user, []string{to}, []byte(msg))
}
