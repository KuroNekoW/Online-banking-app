"""Email OTP delivery for local development.

Local Docker runs use Mailpit (SMTP on 1025, inbox UI on 8025). Tests replace ``deliver_otp``
with an in-memory fake. Do not log or include OTPs in API responses.
"""

import smtplib
from email.message import EmailMessage

from app.core.config import get_settings


def deliver_otp(destination: str, code: str) -> None:
    """Send an OTP email via the configured SMTP relay."""
    settings = get_settings()
    message = EmailMessage()
    message["Subject"] = "Your Mobile Banking verification code"
    message["From"] = settings.email_from
    message["To"] = destination
    message.set_content(
        f"Your verification code is {code}. It expires in {settings.otp_expiry_minutes} minutes. "
        "If you did not request this code, you can ignore this email."
    )
    with smtplib.SMTP(settings.smtp_host, settings.smtp_port, timeout=5) as smtp:
        smtp.send_message(message)
