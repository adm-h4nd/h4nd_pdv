package com.example.mx_cloud_pdv

import android.os.Bundle
import androidx.annotation.Keep
import io.flutter.embedding.android.FlutterActivity

@Keep
class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Aplica o tema LaunchTheme antes do Flutter inicializar
        // Isso garante que a splash customizada apareça imediatamente
        setTheme(com.example.mx_cloud_pdv.R.style.LaunchTheme)
        super.onCreate(savedInstanceState)
    }
    
    // CRÍTICO: onStart() explícito necessário para evitar que R8/ProGuard remova
    // o método do FlutterActivity durante a otimização em release builds
    override fun onStart() {
        super.onStart()
    }
}
