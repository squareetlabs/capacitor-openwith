package com.squareetlabs.capacitor.openwith;

import android.content.Intent;
import android.util.Log;

import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;
import com.getcapacitor.annotation.Permission;

@CapacitorPlugin(
    name = "OpenWith",
    permissions = {
        @Permission(
            strings = {
                android.Manifest.permission.READ_EXTERNAL_STORAGE
            }
        )
    }
)
public class OpenWithPlugin extends Plugin {
    private OpenWith implementation;

    @Override
    public void load() {
        implementation = new OpenWith(getActivity());
    }

    @PluginMethod
    public void addHandler(PluginCall call) {
        call.resolve();
    }

    @PluginMethod
    public void setVerbosity(final PluginCall call) {
        int level = call.getInt("level", 0);
        getBridge().executeOnMainThread(() -> {
            implementation.setVerbosity(level);
            call.resolve();
        });
    }

    @PluginMethod
    public void initialize(PluginCall call) {
        call.resolve();
    }

    @Override
    protected void handleOnNewIntent(Intent intent) {
        super.handleOnNewIntent(intent);
        
        if (implementation.isValidIntent(intent)) {
            try {
                JSObject result = implementation.handleIntent(intent);
                if (result != null) {
                    // Añadir log para debug
                    Log.d("OpenWithPlugin", "Sending event with data: " + result.toString());
                    notifyListeners("receivedFiles", result, true); // El true hace que el evento se entregue incluso si la app está en segundo plano
                }
            } catch (Exception e) {
                Log.e("OpenWithPlugin", "Error handling intent", e);
            }
        }
    }
}
