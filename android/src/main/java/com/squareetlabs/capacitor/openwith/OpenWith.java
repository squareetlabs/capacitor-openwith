package com.squareetlabs.capacitor.openwith;

import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.pm.ApplicationInfo;
import android.net.Uri;
import android.os.Bundle;
import android.provider.CalendarContract;
import android.provider.ContactsContract;
import android.provider.MediaStore;
import android.util.Log;
import androidx.appcompat.app.AppCompatActivity;
import android.database.Cursor;
import java.util.ArrayList;
import java.util.Set;
import android.content.ComponentName;
import android.os.Build;
import android.os.Binder;

import com.getcapacitor.JSObject;
import com.getcapacitor.JSArray;
import org.json.JSONException;

public class OpenWith {
    private static final String TAG = "OpenWith";
    private final AppCompatActivity activity;
    private boolean verbose = false;

    public OpenWith(AppCompatActivity activity) {
        this.activity = activity;
    }

    public void setVerbosity(int level) {
        this.verbose = level > 0;
        if (verbose) {
            Log.d(TAG, "Verbosity set to: " + level);
        }
    }

    public JSObject handleIntent(Intent intent) {
        JSObject ret = new JSObject();
        try {
            JSObject data = new JSObject();
            boolean hasData = false;

            // 1. Información de la aplicación de origen
            addSourceAppInfo(intent, data);

            // 2. Acción del Intent
            String action = intent.getAction();
            if (action != null) {
                data.put("action", action);
                hasData = true;
            }

            // 3. Tipo MIME
                    String type = intent.getType();
                    if (type != null) {
                data.put("type", type);
                hasData = true;
            }

            // 4. Datos del Intent (URI)
            Uri intentData = intent.getData();
            if (intentData != null) {
                data.put("uri", intentData.toString());
                data.put("scheme", intentData.getScheme());
                hasData = true;
            }

            // 5. Procesar extras del Bundle
            Bundle extras = intent.getExtras();
            if (extras != null) {
                processExtras(extras, data);
                hasData = true;
            }

            // 6. Procesar ClipData
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.JELLY_BEAN) {
                if (intent.getClipData() != null) {
                    processClipData(intent, data);
                    hasData = true;
                }
            }

            if (hasData) {
                ret.put("data", data);
            }

            // Debug logging
                    if (verbose) {
                logIntentDetails(intent);
            }

        } catch (Exception e) {
            Log.e(TAG, "Error handling intent", e);
            ret.put("error", e.getMessage());
        }
        
        return ret;
    }

    private void addSourceAppInfo(Intent intent, JSObject data) throws JSONException {
        String sourcePackage = null;

        // Obtener el paquete de la aplicación que originó el share
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
            // Obtener el referrer del intent
            Uri referrer = activity.getReferrer();
            if (referrer != null && "android-app".equals(referrer.getScheme())) {
                sourcePackage = referrer.getHost();
                if (verbose) {
                    Log.d(TAG, "Source package from referrer: " + sourcePackage);
                }
            }
        }

        // Método alternativo si el referrer no está disponible
        if (sourcePackage == null) {
            String[] packages = activity.getPackageManager().getPackagesForUid(Binder.getCallingUid());
            if (packages != null && packages.length > 0) {
                sourcePackage = packages[0];
                if (verbose) {
                    Log.d(TAG, "Source package from calling UID: " + sourcePackage);
                }
            }
        }

        if (sourcePackage != null) {
            try {
                PackageManager pm = activity.getPackageManager();
                ApplicationInfo ai = pm.getApplicationInfo(sourcePackage, 0);
                
                JSObject source = new JSObject();
                source.put("packageName", sourcePackage);
                source.put("applicationName", pm.getApplicationLabel(ai).toString());
                source.put("applicationIcon", String.valueOf(ai.icon));
                data.put("source", source);
                
                if (verbose) {
                    Log.d(TAG, "Source app info: " + source.toString());
                }
            } catch (PackageManager.NameNotFoundException e) {
                if (verbose) {
                    Log.e(TAG, "Error getting source app info", e);
                }
            }
        } else if (verbose) {
            Log.d(TAG, "Could not determine source package");
        }
    }

    private void processExtras(Bundle extras, JSObject data) throws JSONException {
        Set<String> keys = extras.keySet();
        JSObject extrasObj = new JSObject();
        
        for (String key : keys) {
            Object value = extras.get(key);
            if (value != null) {
                // Manejar diferentes tipos de datos
                if (value instanceof String) {
                    extrasObj.put(key, (String) value);
                } else if (value instanceof Integer) {
                    extrasObj.put(key, (Integer) value);
                } else if (value instanceof Long) {
                    extrasObj.put(key, (Long) value);
                } else if (value instanceof Boolean) {
                    extrasObj.put(key, (Boolean) value);
                } else if (value instanceof Float) {
                    extrasObj.put(key, (Float) value);
                } else if (value instanceof Double) {
                    extrasObj.put(key, (Double) value);
                } else if (value instanceof String[]) {
                    JSArray array = new JSArray();
                    for (String s : (String[]) value) {
                        array.put(s);
                    }
                    extrasObj.put(key, array);
                } else if (value instanceof ArrayList) {
                    JSArray array = new JSArray();
                    for (Object o : (ArrayList<?>) value) {
                        if (o instanceof Uri) {
                            array.put(o.toString());
                        } else {
                            array.put(o);
                        }
                    }
                    extrasObj.put(key, array);
                } else if (value instanceof Uri) {
                    extrasObj.put(key, value.toString());
                } else if (value instanceof Bundle) {
                    JSObject nestedBundle = new JSObject();
                    processExtras((Bundle) value, nestedBundle);
                    extrasObj.put(key, nestedBundle);
                }
            }
        }
        
        // Procesar extras específicos comunes
        processCommonExtras(extras, extrasObj);
        
        data.put("extras", extrasObj);
    }

    private void processCommonExtras(Bundle extras, JSObject extrasObj) throws JSONException {
        // Texto y contenido
        if (extras.containsKey(Intent.EXTRA_TEXT)) extrasObj.put("text", extras.getString(Intent.EXTRA_TEXT));
        if (extras.containsKey(Intent.EXTRA_HTML_TEXT)) extrasObj.put("htmlText", extras.getString(Intent.EXTRA_HTML_TEXT));
        if (extras.containsKey(Intent.EXTRA_SUBJECT)) extrasObj.put("subject", extras.getString(Intent.EXTRA_SUBJECT));
        if (extras.containsKey(Intent.EXTRA_TITLE)) extrasObj.put("title", extras.getString(Intent.EXTRA_TITLE));
        
        // Correo electrónico
        if (extras.containsKey(Intent.EXTRA_EMAIL)) extrasObj.put("email", extras.getStringArray(Intent.EXTRA_EMAIL));
        if (extras.containsKey(Intent.EXTRA_CC)) extrasObj.put("cc", extras.getStringArray(Intent.EXTRA_CC));
        if (extras.containsKey(Intent.EXTRA_BCC)) extrasObj.put("bcc", extras.getStringArray(Intent.EXTRA_BCC));
        
        // Teléfono
        if (extras.containsKey(Intent.EXTRA_PHONE_NUMBER)) extrasObj.put("phoneNumber", extras.getString(Intent.EXTRA_PHONE_NUMBER));
        
        // Ubicación
        if (extras.containsKey("latitude")) extrasObj.put("latitude", extras.getDouble("latitude"));
        if (extras.containsKey("longitude")) extrasObj.put("longitude", extras.getDouble("longitude"));
        
        // Medios
        if (extras.containsKey(MediaStore.EXTRA_OUTPUT)) extrasObj.put("mediaOutput", extras.getParcelable(MediaStore.EXTRA_OUTPUT).toString());
        
        // Calendario
        if (extras.containsKey(CalendarContract.Events.TITLE)) extrasObj.put("eventTitle", extras.getString(CalendarContract.Events.TITLE));
        if (extras.containsKey(CalendarContract.Events.DESCRIPTION)) extrasObj.put("eventDescription", extras.getString(CalendarContract.Events.DESCRIPTION));
        if (extras.containsKey(CalendarContract.Events.EVENT_LOCATION)) extrasObj.put("eventLocation", extras.getString(CalendarContract.Events.EVENT_LOCATION));
        
        // Redes sociales y compartir
        if (extras.containsKey("android.intent.extra.STREAM")) {
            Object stream = extras.getParcelable("android.intent.extra.STREAM");
            if (stream instanceof Uri) {
                extrasObj.put("stream", stream.toString());
            }
        }
    }

    private void processClipData(Intent intent, JSObject data) throws JSONException {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.JELLY_BEAN) {
            android.content.ClipData clipData = intent.getClipData();
            if (clipData != null) {
                JSArray clipDataArray = new JSArray();
                for (int i = 0; i < clipData.getItemCount(); i++) {
                    android.content.ClipData.Item item = clipData.getItemAt(i);
                    JSObject clipItem = new JSObject();
                    
                    if (item.getText() != null) clipItem.put("text", item.getText().toString());
                    if (item.getUri() != null) clipItem.put("uri", item.getUri().toString());
                    if (item.getHtmlText() != null) clipItem.put("htmlText", item.getHtmlText());
                    
                    clipDataArray.put(clipItem);
                }
                data.put("clipData", clipDataArray);
            }
        }
    }

    private void logIntentDetails(Intent intent) {
        Log.d(TAG, "Intent Action: " + intent.getAction());
        Log.d(TAG, "Intent Type: " + intent.getType());
        Log.d(TAG, "Intent Data: " + intent.getData());
        Log.d(TAG, "Intent Package: " + intent.getPackage());
        
        Bundle extras = intent.getExtras();
        if (extras != null) {
            for (String key : extras.keySet()) {
                Object value = extras.get(key);
                Log.d(TAG, String.format("Extra [%s]: %s (%s)", 
                    key, value, 
                    value != null ? value.getClass().getName() : "null"));
            }
        }
    }

    public boolean isValidIntent(Intent intent) {
        return intent != null && 
               intent.getAction() != null && 
               (intent.getAction().equals(Intent.ACTION_SEND) || 
                intent.getAction().equals(Intent.ACTION_SEND_MULTIPLE));
    }
}
