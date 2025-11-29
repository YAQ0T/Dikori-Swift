package com.example.dikor_android.network

import com.example.dikor_android.session.Session
import com.example.dikor_android.session.SessionManager
import kotlinx.coroutines.delay
import java.util.UUID

class AuthService(private val sessionManager: SessionManager) {

    suspend fun login(phoneNumber: String, password: String): Result<String> {
        delay(350) // Simulate network work
        val verified = password.length > 5
        return if (verified) {
            val session = Session(
                accessToken = generateToken("access"),
                refreshToken = generateToken("refresh"),
                phoneNumber = phoneNumber,
                isVerified = true
            )
            sessionManager.cacheSession(session, "Logged in as $phoneNumber")
            Result.success("Welcome back! Your session is active.")
        } else {
            sessionManager.requireVerification(
                phoneNumber,
                "We need to verify $phoneNumber before activating your account."
            )
            Result.success("Verification required before continuing.")
        }
    }

    suspend fun register(name: String, phoneNumber: String, password: String): Result<String> {
        delay(500)
        sessionManager.requireVerification(
            phoneNumber,
            "Hi $name, we sent an SMS code to $phoneNumber."
        )
        return Result.success("Registration started. Enter the SMS code to continue.")
    }

    suspend fun verifySmsCode(phoneNumber: String, code: String): Result<String> {
        delay(350)
        val session = Session(
            accessToken = generateToken("access"),
            refreshToken = generateToken("refresh"),
            phoneNumber = phoneNumber,
            isVerified = code.trim().length >= 4
        )
        return if (session.isVerified) {
            sessionManager.cacheSession(session, "Verification complete for $phoneNumber")
            Result.success("Verification accepted. You're signed in.")
        } else {
            Result.failure(IllegalStateException("The code for $phoneNumber looks too short."))
        }
    }

    suspend fun logout(message: String? = "You have signed out.") {
        delay(150)
        sessionManager.clearSession(message)
    }

    private fun generateToken(prefix: String): String = "$prefix-${UUID.randomUUID()}"
}
