/**
 * OTP Radio – Broadcaster page logic.
 * Connects to Phoenix channel, captures mic via MediaRecorder, sends base64 chunks.
 * Load after Phoenix.Socket (phoenix.min.js). Runs in global scope.
 */

(function () {
  "use strict";

  // Latency target <1s: 250ms chunks balance MSE compatibility and latency (200ms works in Chrome/Firefox; 250ms safer for Safari).
  var CHUNK_MS = 250;

  var statusDot = document.getElementById("statusDot");
  var statusText = document.getElementById("statusText");
  var listenerCountEl = document.getElementById("listenerCount");
  var chunksSentEl = document.getElementById("chunksSent");
  var vuLevelEl = document.getElementById("vuLevel");
  var vuFill = document.getElementById("vuFill");
  var logEl = document.getElementById("log");
  var startBtn = document.getElementById("startBtn");
  var stopBtn = document.getElementById("stopBtn");
  var bitrateSelect = document.getElementById("bitrateSelect");
  var noiseSuppression = document.getElementById("noiseSuppression");
  var echoCancellation = document.getElementById("echoCancellation");

  var socket, channel, mediaRecorder, stream, audioContext, analyser;
  var intervalIds = [];
  var chunksSent = 0;
  var listenerCount = 0;

  function log(message, type) {
    type = type || "";
    var div = document.createElement("div");
    div.className = type;
    div.textContent = "[" + new Date().toLocaleTimeString() + "] " + message;
    logEl.insertBefore(div, logEl.firstChild);
  }

  function setStatus(text, state) {
    statusText.textContent = text;
    statusDot.className = "status-dot" + (state ? " " + state : "");
  }

  function updateStats() {
    chunksSentEl.textContent = chunksSent;
    listenerCountEl.textContent = listenerCount;
  }

  function startVuMeter(stream) {
    if (audioContext) {
      try {
        audioContext.close();
      } catch (_) {}
    }
    audioContext = new (window.AudioContext || window.webkitAudioContext)();
    var src = audioContext.createMediaStreamSource(stream);
    analyser = audioContext.createAnalyser();
    analyser.fftSize = 256;
    analyser.smoothingTimeConstant = 0.8;
    src.connect(analyser);
    var data = new Uint8Array(analyser.frequencyBinCount);
    var id = setInterval(function () {
      if (!analyser) return;
      analyser.getByteFrequencyData(data);
      var avg = 0;
      for (var i = 0; i < data.length; i++) avg += data[i];
      avg /= data.length;
      var pct = Math.min(100, (avg / 128) * 100);
      vuFill.style.width = pct + "%";
      vuLevelEl.textContent = Math.round(pct) + "%";
    }, 100);
    intervalIds.push(id);
  }

  function clearIntervals() {
    for (var i = 0; i < intervalIds.length; i++) clearInterval(intervalIds[i]);
    intervalIds = [];
  }

  function getAudioOptions() {
    return {
      echoCancellation: echoCancellation.checked,
      noiseSuppression: noiseSuppression.checked,
      sampleRate: 48000,
    };
  }

  function getBitrate() {
    return parseInt(bitrateSelect.value, 10);
  }

  function startBroadcast() {
    var options = {
      mimeType: "audio/webm;codecs=opus",
      audioBitsPerSecond: getBitrate(),
    };
    if (!MediaRecorder.isTypeSupported(options.mimeType)) {
      log("audio/webm;codecs=opus not supported", "error");
      setStatus("Codec not supported", "failed");
      return;
    }
    mediaRecorder = new MediaRecorder(stream, options);
    mediaRecorder.ondataavailable = function (event) {
      if (event.data.size > 0) {
        var reader = new FileReader();
        reader.onloadend = function () {
          var base64 = reader.result.split(",")[1];
          channel
            .push("audio_chunk", { data: base64 })
            .receive("ok", function () {
              chunksSent++;
              updateStats();
              if (chunksSent % 20 === 0) log("Sent " + chunksSent + " chunks");
            })
            .receive("error", function (err) {
              log("Send error: " + JSON.stringify(err), "error");
            });
        };
        reader.readAsDataURL(event.data);
      }
    };
    mediaRecorder.onerror = function (e) {
      log("MediaRecorder error: " + (e.error && e.error.message ? e.error.message : "unknown"), "error");
      setStatus("Recording error", "failed");
    };
    mediaRecorder.start(CHUNK_MS);
    setStatus("LIVE – Broadcasting", "live");
    startBtn.disabled = true;
    stopBtn.disabled = false;
    log("Broadcasting started (Opus @ " + getBitrate() / 1000 + " kbps, " + CHUNK_MS + "ms chunks)");
  }

  function connectAndJoin() {
    return new Promise(function (resolve, reject) {
      socket = new Phoenix.Socket("/socket", { params: {} });
      socket.onOpen(function () {
        setStatus("Connected – Starting broadcast...", "live");
        if (mediaRecorder && mediaRecorder.state !== "inactive") {
          channel = socket.channel("broadcaster:one", {});
          channel.join()
            .receive("ok", function () {
              setStatus("LIVE – Broadcasting", "live");
              log("Reconnected and re-joined channel");
            })
            .receive("error", function (r) {
              log("Re-join failed: " + JSON.stringify(r), "error");
            });
        }
      });
      socket.onError(function () {
        setStatus("Connection error", "failed");
      });
      socket.onClose(function () {
        if (mediaRecorder && mediaRecorder.state !== "inactive") {
          setStatus("Reconnecting...", "reconnecting");
        }
      });
      socket.connect();
      channel = socket.channel("broadcaster:one", {});
      channel.onClose(function () {
        if (mediaRecorder && mediaRecorder.state !== "inactive") {
          setStatus("Channel closed", "failed");
        }
      });
      channel.onError(function () {
        setStatus("Channel error", "failed");
      });
      channel
        .join()
        .receive("ok", function () {
          log("Joined broadcaster channel");
          resolve();
        })
        .receive("error", function (resp) {
          log("Join failed: " + JSON.stringify(resp), "error");
          reject(new Error(resp.reason || "join failed"));
        });
    });
  }

  function pollListenerCount() {
    if (!channel || !channel.canPush) return;
    channel.push("listener_count", {}).receive("ok", function (payload) {
      listenerCount = payload.count;
      updateStats();
    });
  }

  startBtn.addEventListener("click", function () {
    setStatus("Connecting...", "");
    navigator.mediaDevices
      .getUserMedia({ audio: getAudioOptions() })
      .then(function (s) {
        stream = s;
        log("Microphone access granted");
        return connectAndJoin();
      })
      .then(function () {
        startVuMeter(stream);
        startBroadcast();
        intervalIds.push(setInterval(pollListenerCount, 2000));
      })
      .catch(function (err) {
        if (err.name === "NotAllowedError") {
          setStatus("Microphone access denied", "failed");
          log("Microphone permission denied. Enable it in browser settings.", "error");
        } else {
          setStatus("Failed to start", "failed");
          log("Error: " + err.message, "error");
        }
        startBtn.disabled = false;
      });
  });

  stopBtn.addEventListener("click", function () {
    if (mediaRecorder && mediaRecorder.state !== "inactive") mediaRecorder.stop();
    if (stream) stream.getTracks().forEach(function (t) { t.stop(); });
    clearIntervals();
    if (channel) channel.leave();
    if (socket) socket.disconnect();
    setStatus("Stopped", "");
    startBtn.disabled = false;
    stopBtn.disabled = true;
    listenerCount = 0;
    chunksSent = 0;
    updateStats();
    log("Broadcast ended. Chunks sent: " + chunksSent);
  });

})();
