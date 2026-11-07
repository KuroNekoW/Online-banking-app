"""OTP delivery boundary.

Replace ``deliver_otp`` with an email/SMS provider integration in deployment. Tests replace it
with an in-memory fake, so OTP secrets never need to be exposed by HTTP responses.
"""


def deliver_otp(destination: str, code: str) -> None:
    """Deliver an OTP without logging its secret value.

    This is intentionally a no-op until a provider is configured.
    """
    del destination, code
