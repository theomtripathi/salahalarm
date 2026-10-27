# Canela Font Setup Instructions

## Problem
The Canela fonts are not loading because they're not being included in the app bundle during build.

## Solution

### Step 1: Add Fonts to Xcode Project Target

1. **Open Xcode** and select your project in the navigator
2. **Select the "Ramadan Pro" target** (not the widget extension)
3. Go to **Build Phases** tab
4. Expand **"Copy Bundle Resources"**
5. Click the **"+"** button
6. Navigate to `Ramadan Pro/CustomFont/canela-text-trial/`
7. **Select all 12 Canela font files**:
   - Canela-Thin-Trial.otf
   - Canela-Light-Trial.otf
   - Canela-Regular-Trial.otf
   - Canela-Medium-Trial.otf
   - Canela-Bold-Trial.otf
   - Canela-Black-Trial.otf
   - Canela-ThinItalic-Trial.otf
   - Canela-LightItalic-Trial.otf
   - Canela-RegularItalic-Trial.otf
   - Canela-MediumItalic-Trial.otf
   - Canela-BoldItalic-Trial.otf
   - Canela-BlackItalic-Trial.otf
8. Click **"Add"**

### Step 2: Verify Info.plist Configuration

The `Ramadan-Pro-Info.plist` already has the correct font paths:
```xml
<key>UIAppFonts</key>
<array>
    <string>CustomFont/canela-text-trial/Canela-Thin-Trial.otf</string>
    <!-- ... other fonts ... -->
</array>
```

**IMPORTANT**: Since your project uses `GENERATE_INFOPLIST_FILE = YES`, you need to ensure the custom Info.plist is being used:

1. In Xcode, select the **"Ramadan Pro" target**
2. Go to **Build Settings**
3. Search for **"Info.plist File"**
4. Verify it shows: `Ramadan-Pro-Info.plist`

### Step 3: Alternative - Add Fonts via Build Settings

If the Info.plist approach doesn't work, you can add fonts via build settings:

1. Select the **"Ramadan Pro" target**
2. Go to **Build Settings**
3. Search for **"UI App Fonts"** or **"INFOPLIST_KEY_UIAppFonts"**
4. Add the font paths (one per line):
   ```
   CustomFont/canela-text-trial/Canela-Thin-Trial.otf
   CustomFont/canela-text-trial/Canela-Light-Trial.otf
   CustomFont/canela-text-trial/Canela-Regular-Trial.otf
   CustomFont/canela-text-trial/Canela-Medium-Trial.otf
   CustomFont/canela-text-trial/Canela-Bold-Trial.otf
   CustomFont/canela-text-trial/Canela-Black-Trial.otf
   CustomFont/canela-text-trial/Canela-ThinItalic-Trial.otf
   CustomFont/canela-text-trial/Canela-LightItalic-Trial.otf
   CustomFont/canela-text-trial/Canela-RegularItalic-Trial.otf
   CustomFont/canela-text-trial/Canela-MediumItalic-Trial.otf
   CustomFont/canela-text-trial/Canela-BoldItalic-Trial.otf
   CustomFont/canela-text-trial/Canela-BlackItalic-Trial.otf
   ```

### Step 4: Clean and Rebuild

1. In Xcode: **Product → Clean Build Folder** (Shift+Cmd+K)
2. **Product → Build** (Cmd+B)
3. Run the app on a device or simulator

### Step 5: Verify Fonts Are Loading

After rebuilding, check the console logs. You should **NOT** see:
```
FontParser could not open filePath...
```

If you still see errors, the fonts are not being copied. Double-check:
- Fonts are in "Copy Bundle Resources"
- Font paths in Info.plist match the actual file structure
- The app bundle contains the fonts (check in Xcode: Product → Show Build Folder → find the .app bundle)

## Font PostScript Names

The code uses these PostScript names (verified correct):
- `CanelaTrial-Thin`
- `CanelaTrial-Light`
- `CanelaTrial-Regular`
- `CanelaTrial-Medium`
- `CanelaTrial-Bold`
- `CanelaTrial-Black`

These match the font files' internal PostScript names.
