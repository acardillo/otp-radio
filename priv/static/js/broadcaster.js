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
  var statusLiveWrap = document.getElementById("statusLiveWrap");
  var listenerCountEl = document.getElementById("listenerCount");
  var chunksSentEl = document.getElementById("chunksSent");
  var vuLevelEl = document.getElementById("vuLevel");
  var vuLevelUnitEl = document.getElementById("vuLevelUnit");
  var vuFill = document.getElementById("vuFill");
  var logEl = document.getElementById("log");
  var broadcastBtn = document.getElementById("broadcastBtn");
  var bitrateSelect = document.getElementById("bitrateSelect");
  var noiseSuppression = document.getElementById("noiseSuppression");
  var echoCancellation = document.getElementById("echoCancellation");
  var stationButtonsEl = document.getElementById("stationButtons");
  var inputSelectEl = document.getElementById("inputSelect");
  var selectedStationId = null;

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

  function setStatus(_text, state) {
    statusDot.className = "status-dot" + (state ? " " + state : "");
    if (statusLiveWrap) statusLiveWrap.style.display = state === "live" ? "" : "none";
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
      var normalized = (avg / 255) + 0.001;
      var db = 20 * Math.log10(normalized);
      if (db <= -60) {
        vuLevelEl.textContent = "No signal";
        vuLevelUnitEl.textContent = "";
        if (vuLevelEl.parentElement) vuLevelEl.parentElement.classList.add("vu-db-idle");
      } else {
        vuLevelEl.textContent = Math.round(db);
        vuLevelUnitEl.textContent = " dB";
        if (vuLevelEl.parentElement) vuLevelEl.parentElement.classList.remove("vu-db-idle");
      }
    }, 100);
    intervalIds.push(id);
  }

  function clearIntervals() {
    for (var i = 0; i < intervalIds.length; i++) clearInterval(intervalIds[i]);
    intervalIds = [];
  }

  function getAudioOptions() {
    var audio = {
      echoCancellation: echoCancellation.checked,
      noiseSuppression: noiseSuppression.checked,
      sampleRate: 48000,
    };
    var deviceId = inputSelectEl && inputSelectEl.value ? inputSelectEl.value.trim() : "";
    if (deviceId) audio.deviceId = { ideal: deviceId };
    return audio;
  }

  function loadInputDevices() {
    if (!inputSelectEl || !navigator.mediaDevices || !navigator.mediaDevices.enumerateDevices) return;
    navigator.mediaDevices.enumerateDevices().then(function (devices) {
      var audioInputs = devices.filter(function (d) { return d.kind === "audioinput"; });
      var selected = inputSelectEl.value;
      inputSelectEl.innerHTML = "";
      var defaultOpt = document.createElement("option");
      defaultOpt.value = "";
      defaultOpt.textContent = "Default microphone";
      inputSelectEl.appendChild(defaultOpt);
      audioInputs.forEach(function (d, i) {
        var opt = document.createElement("option");
        opt.value = d.deviceId;
        opt.textContent = d.label || "Microphone " + (i + 1);
        inputSelectEl.appendChild(opt);
        if (d.deviceId === selected) opt.selected = true;
      });
    }).catch(function () {});
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
    broadcastBtn.textContent = "Stop";
    broadcastBtn.dataset.tooltip = "Disconnect and end stream";
    broadcastBtn.disabled = false;
    log("Broadcasting started (Opus @ " + getBitrate() / 1000 + " kbps, " + CHUNK_MS + "ms chunks)");
  }

  function getStationId() {
    return selectedStationId;
  }

  function setStationActive(btn) {
    var btns = stationButtonsEl.querySelectorAll(".station-btn");
    for (var i = 0; i < btns.length; i++) btns[i].classList.remove("active");
    if (btn) btn.classList.add("active");
  }

  function disconnectAndStop() {
    if (mediaRecorder && mediaRecorder.state !== "inactive") mediaRecorder.stop();
    if (stream) stream.getTracks().forEach(function (t) { t.stop(); });
    clearIntervals();
    if (channel) channel.leave();
    if (socket) socket.disconnect();
    setStatus("Stopped", "");
    broadcastBtn.textContent = "Start";
    broadcastBtn.dataset.tooltip = "Request mic and start streaming";
    broadcastBtn.disabled = false;
    vuLevelEl.textContent = "No signal";
    if (vuLevelUnitEl) vuLevelUnitEl.textContent = "";
    if (vuLevelEl.parentElement) vuLevelEl.parentElement.classList.add("vu-db-idle");
    if (vuFill) vuFill.style.width = "0%";
    var sent = chunksSent;
    listenerCount = 0;
    chunksSent = 0;
    updateStats();
    if (sent > 0) log("Broadcast ended. Chunks sent: " + sent);
  }

  function loadStations() {
    if (!stationButtonsEl) return;
    stationButtonsEl.innerHTML = "";
    fetch("/api/stations")
      .then(function (r) { return r.json(); })
      .then(function (stations) {
        if (stations.length === 0) return;
        stations.sort(function (a, b) { return (a.name || "").localeCompare(b.name || ""); });
        stations.forEach(function (s, index) {
          var btn = document.createElement("button");
          btn.type = "button";
          btn.className = "station-btn" + (index === 0 ? " active" : "");
          btn.dataset.stationId = s.id;
          btn.textContent = s.name;
          btn.title = "Broadcast to " + s.name;
          if (index === 0) selectedStationId = s.id;
          btn.addEventListener("click", function () {
            if (mediaRecorder && mediaRecorder.state !== "inactive") {
              disconnectAndStop();
            }
            selectedStationId = btn.dataset.stationId;
            setStationActive(btn);
          });
          stationButtonsEl.appendChild(btn);
        });
      })
      .catch(function () {});
  }

  function connectAndJoin() {
    var stationId = getStationId();
    if (!stationId) {
      return Promise.reject(new Error("Select a station"));
    }
    return new Promise(function (resolve, reject) {
      socket = new Phoenix.Socket("/socket", { params: {} });
      socket.onOpen(function () {
        setStatus("Connected – Starting broadcast...", "live");
        if (mediaRecorder && mediaRecorder.state !== "inactive") {
          channel = socket.channel("broadcaster:" + stationId, {});
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
      channel = socket.channel("broadcaster:" + stationId, {});
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

  broadcastBtn.addEventListener("click", function () {
    if (mediaRecorder && mediaRecorder.state !== "inactive") {
      disconnectAndStop();
      return;
    }
    setStatus("Connecting...", "");
    broadcastBtn.disabled = true;
    navigator.mediaDevices
      .getUserMedia({ audio: getAudioOptions() })
      .then(function (s) {
        stream = s;
        log("Microphone access granted");
        loadInputDevices();
        return connectAndJoin();
      })
      .then(function () {
        startVuMeter(stream);
        startBroadcast();
        intervalIds.push(setInterval(pollListenerCount, 2000));
      })
      .catch(function (err) {
        if (err.message === "Select a station") {
          setStatus("Select a station", "failed");
          log("Select a station from the dropdown", "error");
        } else if (err.name === "NotAllowedError") {
          setStatus("Microphone access denied", "failed");
          log("Microphone permission denied. Enable it in browser settings.", "error");
        } else {
          setStatus("Failed to start", "failed");
          log("Error: " + err.message, "error");
        }
        broadcastBtn.disabled = false;
      });
  });

  var logCopyBtn = document.getElementById("logCopyBtn");
  if (logCopyBtn) {
    logCopyBtn.addEventListener("click", function () {
      var lines = [];
      for (var i = logEl.children.length - 1; i >= 0; i--) lines.push(logEl.children[i].textContent);
      var text = lines.length ? lines.join("\n") : "(no log entries yet)";
      navigator.clipboard.writeText(text).then(function () {
        var orig = logCopyBtn.textContent;
        logCopyBtn.textContent = "Copied!";
        setTimeout(function () { logCopyBtn.textContent = orig; }, 1500);
      }).catch(function () {});
    });
  }

  if (stationButtonsEl) loadStations();
  if (inputSelectEl) loadInputDevices();
})();
