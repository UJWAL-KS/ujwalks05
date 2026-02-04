# 📢 Advanced Speech Analyzer – Real-Time Voice Analysis (MATLAB)

The **Advanced Speech Analyzer** is a real-time MATLAB-based tool that captures live microphone audio and extracts key speech parameters including **pitch**, **volume**, **formants**, and **spectrogram data**.  
It provides a complete GUI with live plots, user controls, visual indicators, and alert notifications when speech crosses threshold limits.

---

## 🎯 Features

### 🔊 Real-Time Audio Capture
- Captures microphone input using `audioDeviceReader`
- Adjustable sample rate
- Low-latency DSP pipeline

### 🎵 Pitch Detection
- Autocorrelation-based pitch estimation
- Smooth pitch indicator
- Pitch gauge with safe–danger zones
- Pitch threshold alerts

### 🔈 Volume Monitoring
- RMS-based volume level detection
- Real-time volume bar
- Color-coded volume alerts (green → yellow → red)

### 🧠 Formant Tracking
- LPC-based formant estimation
- Displays F1, F2, and F3 frequencies in real-time

### 🎼 Spectrogram Visualization
- Live scrolling spectrogram
- High-resolution frequency tracking

### 🎚️ User Controls
- Start / Stop / Reset buttons
- Adjustable sensitivity levels
- Custom thresholds for pitch & volume

### ⚠️ Smart Alerts
- High/Low pitch warning
- High volume warning
- Silence / no-voice detection

---

## 🛠️ Technologies Used

| Component | Technology |
|----------|------------|
| Programming | MATLAB |
| Audio Input | audioDeviceReader |
| DSP | Autocorrelation, RMS Volume, LPC Formants |
| Visualization | MATLAB UI (uiaxes, gauges) |
| GUI | uifigure + real-time updates |

---

## 📁 Project Structure

