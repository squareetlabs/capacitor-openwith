package com.squareetlabs.capacitor.openwith;

import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Bundle;

import com.getcapacitor.BridgeActivity;

public class OpenWithActivity extends BridgeActivity {
    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        
        // Obtener el intent que inició esta activity
        Intent intent = getIntent();
        
        // Obtener el package name de la aplicación
        String packageName = getPackageName();
        
        try {
            // Obtener el launcher activity (MainActivity) de la aplicación
            PackageManager pm = getPackageManager();
            Intent launchIntent = pm.getLaunchIntentForPackage(packageName);
            
            if (launchIntent != null) {
                // Copiar la acción y tipo del intent original
                launchIntent.setAction(intent.getAction());
                launchIntent.setType(intent.getType());
                
                // Copiar los extras del intent original
                if (intent.getExtras() != null) {
                    launchIntent.putExtras(intent.getExtras());
                }
                
                // Asegurarnos de que se crea una nueva instancia
                launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
                
                // Iniciar la actividad principal
                startActivity(launchIntent);
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
        
        // Cerrar esta activity
        finish();
    }
} 