package com.example.dikor_android.auth

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle

@Composable
fun AuthFlowScreen(viewModel: AuthViewModel) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val authState = uiState.authState
    val statusMessage = uiState.statusMessage

    Scaffold { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .padding(24.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            Text(
                text = "Auth Flow",
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.Bold
            )

            statusMessage?.let {
                Text(
                    text = it,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.secondary
                )
            }

            when (authState) {
                AuthState.Loading -> LoadingState()
                is AuthState.Unauthenticated -> UnauthenticatedState(viewModel, uiState)
                is AuthState.NeedsVerification -> VerificationState(viewModel, uiState)
                is AuthState.Authenticated -> AuthenticatedState(viewModel, uiState)
            }
        }
    }
}

@Composable
private fun LoadingState() {
    Column(
        modifier = Modifier.fillMaxSize(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        CircularProgressIndicator()
        Spacer(modifier = Modifier.height(12.dp))
        Text("Restoring your session...")
    }
}

@Composable
private fun UnauthenticatedState(viewModel: AuthViewModel, uiState: AuthUiState) {
    var showLogin by remember { mutableStateOf(true) }
    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        OutlinedButton(onClick = { showLogin = true }) {
            Text("Login")
        }
        OutlinedButton(onClick = { showLogin = false }) {
            Text("Register")
        }
    }
    if (showLogin) {
        LoginForm(viewModel, uiState)
    } else {
        RegistrationForm(viewModel, uiState)
    }
}

@Composable
private fun LoginForm(viewModel: AuthViewModel, uiState: AuthUiState) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text("Sign in with your phone and password")
        OutlinedTextField(
            modifier = Modifier.fillMaxWidth(),
            value = uiState.phoneNumber,
            onValueChange = viewModel::updatePhone,
            label = { Text("Phone number") }
        )
        OutlinedTextField(
            modifier = Modifier.fillMaxWidth(),
            value = uiState.password,
            onValueChange = viewModel::updatePassword,
            label = { Text("Password") }
        )
        Button(
            modifier = Modifier.fillMaxWidth(),
            enabled = !uiState.isWorking,
            onClick = viewModel::login
        ) {
            Text(if (uiState.isWorking) "Signing in..." else "Login")
        }
    }
}

@Composable
private fun RegistrationForm(viewModel: AuthViewModel, uiState: AuthUiState) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text("Create a new account")
        OutlinedTextField(
            modifier = Modifier.fillMaxWidth(),
            value = uiState.name,
            onValueChange = viewModel::updateName,
            label = { Text("Full name") }
        )
        OutlinedTextField(
            modifier = Modifier.fillMaxWidth(),
            value = uiState.phoneNumber,
            onValueChange = viewModel::updatePhone,
            label = { Text("Phone number") }
        )
        OutlinedTextField(
            modifier = Modifier.fillMaxWidth(),
            value = uiState.password,
            onValueChange = viewModel::updatePassword,
            label = { Text("Password") }
        )
        Button(
            modifier = Modifier.fillMaxWidth(),
            enabled = !uiState.isWorking,
            onClick = viewModel::register
        ) {
            Text(if (uiState.isWorking) "Submitting..." else "Register")
        }
    }
}

@Composable
private fun VerificationState(viewModel: AuthViewModel, uiState: AuthUiState) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(
            text = "We texted a code to ${uiState.authState.let { (it as AuthState.NeedsVerification).phoneNumber }}",
            style = MaterialTheme.typography.bodyLarge,
            fontWeight = FontWeight.Medium
        )
        OutlinedTextField(
            modifier = Modifier.fillMaxWidth(),
            value = uiState.verificationCode,
            onValueChange = viewModel::updateVerificationCode,
            label = { Text("SMS verification code") }
        )
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Button(
                modifier = Modifier.weight(1f),
                enabled = !uiState.isWorking,
                onClick = viewModel::verifyCode
            ) {
                Text(if (uiState.isWorking) "Verifying..." else "Submit code")
            }
            OutlinedButton(
                modifier = Modifier.weight(1f),
                onClick = viewModel::logout
            ) {
                Text("Cancel")
            }
        }
    }
}

@Composable
private fun AuthenticatedState(viewModel: AuthViewModel, uiState: AuthUiState) {
    val session = (uiState.authState as AuthState.Authenticated).session
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(
            text = "Signed in as ${session.phoneNumber}",
            style = MaterialTheme.typography.bodyLarge,
            fontWeight = FontWeight.Medium
        )
        Text(
            text = "Access token\n${session.accessToken}",
            style = MaterialTheme.typography.bodySmall
        )
        Text(
            text = "Refresh token\n${session.refreshToken}",
            style = MaterialTheme.typography.bodySmall
        )
        Text(
            text = if (session.isVerified) "SMS verified" else "Awaiting verification",
            color = if (session.isVerified) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.error
        )

        uiState.serviceStatus?.let {
            Text(text = it, style = MaterialTheme.typography.bodyMedium)
        }

        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Button(
                modifier = Modifier.weight(1f),
                enabled = !uiState.isWorking,
                onClick = viewModel::refreshSessionClients
            ) {
                Text(if (uiState.isWorking) "Refreshing..." else "Refresh clients")
            }
            OutlinedButton(
                modifier = Modifier.weight(1f),
                onClick = viewModel::logout
            ) {
                Text("Logout")
            }
        }
    }
}
