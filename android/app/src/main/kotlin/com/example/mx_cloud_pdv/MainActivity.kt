package com.example.mx_cloud_pdv

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Aplica o tema LaunchTheme antes do Flutter inicializar
        // Isso garante que a splash customizada apareça imediatamente
        setTheme(com.example.mx_cloud_pdv.R.style.LaunchTheme)
        super.onCreate(savedInstanceState)
    }
}
