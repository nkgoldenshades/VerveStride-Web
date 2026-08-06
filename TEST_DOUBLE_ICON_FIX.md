# Test Guide: Double Loading Icons Fix

## ⚠️ IMPORTANT: Restart Required
Press **`R`** (capital R) in your terminal to **restart the app**. Hot reload (`r`) won't work for service state changes.

## Test 1: Single Loading Indicator
**Goal**: Verify only ONE loading indicator shows at a time

### Steps:
1. Open Floating AI (purple button)
2. Send a message: "Hello"
3. **Expected**: See thinking dots bubble on left side
4. **Expected**: NO spinner in AI Settings send button

5. Open Settings → AI Settings
6. Send a message: "Test"
7. **Expected**: See spinner in send button
8. **Expected**: NO thinking dots in Floating AI (if visible)

### ✅ Pass Criteria:
- Only ONE loading indicator visible at a time
- No double icons showing simultaneously

---

## Test 2: Voice Toggle Works
**Goal**: Verify AI only speaks when voice is enabled

### Steps:
1. Open Settings → AI Settings
2. Turn **OFF** "Voice Commands" toggle
3. Save settings
4. Open Floating AI
5. Send a message: "Tell me a joke"
6. **Expected**: AI responds with text
7. **Expected**: AI does NOT speak (no audio)

8. Go back to Settings → AI Settings
9. Turn **ON** "Voice Commands" toggle
10. Save settings
11. Send another message in Floating AI
12. **Expected**: AI responds with text AND speaks

### ✅ Pass Criteria:
- Voice OFF = No audio output
- Voice ON = Audio output works

---

## Test 3: Attachment Button Works
**Goal**: Verify attachment button is clickable when not processing

### Steps:
1. Open Floating AI
2. Look for the 📷+ button (center of input row)
3. Click the button
4. **Expected**: Menu appears with options:
   - Add photos & files
   - Take a photo
   - Create image
   - Live video session

5. Send a message to trigger processing
6. While processing, try clicking 📷+ button
7. **Expected**: Button is disabled (grayed out)

8. Wait for response to complete
9. Try clicking 📷+ button again
10. **Expected**: Menu appears again

### ✅ Pass Criteria:
- Button works when NOT processing
- Button disabled DURING processing
- Button works again AFTER processing

---

## Test 4: Cross-Screen Sync
**Goal**: Verify both screens show same processing state

### Steps:
1. Open Floating AI and AI Settings side by side (if possible)
2. Send message from Floating AI
3. **Expected**: 
   - Floating AI shows thinking dots
   - AI Settings send button shows spinner
   - Both update at the same time

4. Wait for response
5. **Expected**: Both indicators disappear at the same time

### ✅ Pass Criteria:
- Both screens sync processing state
- No delay between updates

---

## Test 5: New Thread Creation
**Goal**: Verify new threads work correctly

### Steps:
1. Open Floating AI
2. Click "New Thread" button (if visible)
3. Send a message: "New conversation"
4. **Expected**: New thread created with title based on message
5. **Expected**: Only ONE loading indicator shows

6. Open AI Settings chat
7. **Expected**: Same conversation visible
8. **Expected**: Same processing state

### ✅ Pass Criteria:
- New threads work in both screens
- Processing state syncs correctly

---

## Known Issues (Not Fixed Yet)
These issues are NOT addressed in this fix:
- Wake word listening (unused method warning)
- Continuous voice watchdog (unused method warning)

---

## If Tests Fail

### Double icons still showing:
1. Make sure you pressed **`R`** to restart (not just `r`)
2. Check console for errors
3. Verify `UnifiedAIChatService.isProcessing` is being used

### Voice still speaking when OFF:
1. Check AI Settings → Voice Commands is OFF
2. Press Save Settings button
3. Restart app with `R`
4. Try again

### Attachment button not working:
1. Check if Photo Analysis is enabled in AI Settings
2. Make sure you're not in processing state
3. Check console for errors

---

## Success Criteria Summary
✅ Only ONE loading indicator at a time  
✅ Voice toggle controls audio output  
✅ Attachment button works when not processing  
✅ Both screens sync processing state  
✅ New threads work correctly  
