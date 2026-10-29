# Rescate de Alimentos — Los 3A

App Flutter (Cliente / Restaurante) para rescatar comida: los restaurantes
publican paquetes con descuento y los clientes los apartan con un PIN que se
valida al recoger. Usa Firebase y Gemini.

| EDT | Tarea | Estado | Archivos |
| --- | --- | --- | --- |
| 1.1 | Modelo de BD (Firestore + SQLite) | ✅ | `lib/models/`, `lib/services/local_db.dart`, `lib/services/secure_storage_service.dart`, `firestore.indexes.json` |
| 1.2 | Flujo UX/UI | Pendiente (Figma) | — |
| 1.3 | Contratos de API e IA | Parcial | `lib/models/analisis_ia.dart`, `test/analisis_ia_test.dart` |
| 2.1 | Proyecto Flutter y Git | ✅ | todo el repo |
| 2.2 | Firebase | ✅ | `firebase.json`, `firestore.rules`, `storage.rules` |
| 2.3 | SDK de IA | ✅ | `lib/services/gemini_service.dart` |
| 3.1 | Auth clientes y restaurantes | ✅ | `lib/services/auth_service.dart`, `lib/providers/session_provider.dart` |
| 3.2 | Análisis multimodal con IA | Servicio listo, falta conectarlo a la UI | `lib/services/gemini_service.dart` |
| 3.3 | Precio recomendado y CRUD de ofertas | Parcial (sin precio sugerido ni edición) | `lib/services/firestore_service.dart` |
| 3.4 | Cloud Functions + FCM | Pendiente | — |
| 4.1 | UI registro/login y rol | ✅ | `lib/views/auth_view.dart` |
| 4.2 | UI negocio: cámara, preview IA y precio | Parcial (solo galería) | `lib/views/restaurant/` |
| 4.3 | UI cliente: feed y detalle | Parcial (sin pantalla de detalle) | `lib/views/client/` |
| 4.4 | UI reserva: generar y validar clave | ✅ | `lib/views/client/`, `lib/views/restaurant/deliveries_tab.dart` |

## Requisitos

- Flutter 3.24 o superior (`flutter --version`)
- Node.js 22 y Firebase CLI: `npm install -g firebase-tools`
- FlutterFire CLI: `dart pub global activate flutterfire_cli`

## 2.1 Crear el proyecto y el repositorio

```bash
cd rescate_alimentos
flutter create . --org com.los3a --project-name rescate_alimentos --platforms android,ios
rm test/widget_test.dart          # el de plantilla usa MyApp, que aquí no existe
flutter pub get
flutter pub upgrade --tighten     # fija versiones en pubspec.yaml

git init
git add .
git commit -m "Fases 1 y 2: modelo de datos, configuración Firebase e IA"
git branch -M main
git remote add origin https://github.com/<usuario>/rescate_alimentos.git
git push -u origin main
```

Ramas: `main` ← `develop` ← `feature/<EDT>-<nombre>`, con Pull Request
revisado por otro integrante.

Android: en `android/app/build.gradle` subir `minSdk` a **23**.

## 2.2 Configurar Firebase

1. En https://console.firebase.google.com crear el proyecto (plan **Blaze**;
   lo pide Firebase AI Logic, con cuota gratuita).
2. Activar **Authentication → Correo/contraseña**, **Firestore** (modo
   producción), **Storage** y **Cloud Messaging**.
3. Conectar la app (genera `lib/firebase_options.dart`; las llaves NO se suben a Git):
   ```bash
   firebase login
   flutterfire configure --project=<id-del-proyecto>
   ```
4. Publicar reglas e índices:
   ```bash
   firebase use <id-del-proyecto>
   firebase deploy --only firestore:rules,firestore:indexes,storage
   ```

## 2.3 Configurar Gemini (Firebase AI Logic)

1. Consola de Firebase → **AI Logic** → *Get started* → **Gemini Developer API**.
   La API key queda en Firebase, no en el código.
2. El modelo está en `GeminiService.nombreModelo` (`gemini-2.5-flash`).
3. Antes de publicar la app: activar **App Check**.

## Verificar

```bash
flutter test     # contrato de IA y modelos
flutter run
```
