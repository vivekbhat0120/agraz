package mailer

import (
	"strings"
	"testing"
)

func TestBuildMessageSendsToRecipientNotSender(t *testing.T) {
	msg := buildMessage(
		"Agraz",
		"nanunandi@gmail.com",
		"customer@example.com",
		"Your Agraz password reset code",
		"Your Agraz password reset code is: 123456\n",
	)
	if !strings.Contains(msg, "From: Agraz <nanunandi@gmail.com>") {
		t.Fatalf("From header: %q", msg)
	}
	if !strings.Contains(msg, "To: customer@example.com") {
		t.Fatalf("To header missing customer: %q", msg)
	}
	if strings.Contains(msg, "To: nanunandi@gmail.com") {
		t.Fatal("To header must not be the SMTP login")
	}
}
