package com.example.dikor_android.session

data class Session(
    val accessToken: String,
    val refreshToken: String,
    val phoneNumber: String,
    val isVerified: Boolean
)
