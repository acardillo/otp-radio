/**
 * OTP Radio – Listener page logic.
 * Connects to Phoenix channel, receives base64 chunks, feeds MSE for playback.
 * Load after Phoenix.Socket (phoenix.min.js). Runs in global scope.
 */

(function () {
  "use strict";

  var START_BUFFER_SEC = 0.2;
  var MAX_JITTER_QUEUE = 30;
  var LATENCY_SAMPLE_INTERVAL_MS = 500;

  var statusDot = document.getElementById("statusDot");
  var statusText = document.getElementById("statusText");
  var bufferSecEl = document.getElementById("bufferSec");
  var chunksPerSecEl = document.getElementById("chunksPerSec");
  var latencyMsEl = document.getElementById("latencyMs");
  var queueLenEl = document.getElementById("queueLen");
  var logEl = document.getElementById("log");
  var playBtn = document.getElementById("playBtn");
  var audioPlayer = document.getElementById("audioPlayer");

  var stationSelectEl = document.getElementById("stationSelect");
  var mediaSource, sourceBuffer, socket, channel;
  var chunkQueue = [];
  var isAppending = false;
  var chunkCount = 0;
  var lastSequence = -1;
  var chunksInLastSecond = 0;
  var lastSecondTime = Date.now();
  var latencySampleIntervalId = null;
  var sourceBufferErrorCount = 0;

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
    var now = Date.now();
    if (now - lastSecondTime >= 1000) {
      chunksPerSecEl.textContent = chunksInLastSecond;
      chunksInLastSecond = 0;
      lastSecondTime = now;
    }
    queueLenEl.textContent = chunkQueue.length;
    if (isSourceUsable() && sourceBuffer.buffered.length > 0) {
      var bufEnd = sourceBuffer.buffered.end(0);
      var current = audioPlayer.currentTime;
      var bufferedAhead = Math.max(0, bufEnd - current);
      bufferSecEl.textContent = bufferedAhead.toFixed(1);
    }
  }

  function estimateLatencyMs() {
    if (!isSourceUsable() || sourceBuffer.buffered.length === 0) return null;
    return Math.round((sourceBuffer.buffered.end(0) - audioPlayer.currentTime) * 1000);
  }

  function isSourceUsable() {
    return mediaSource && mediaSource.readyState === "open" && sourceBuffer;
  }

  function getSelectedStationId() {
    if (!stationSelectEl || !stationSelectEl.value) return null;
    return stationSelectEl.value.trim() || null;
  }

  function loadStations() {
    if (!stationSelectEl) return;
    stationSelectEl.innerHTML = "<option value=\"\">Loading…</option>";
    fetch("/api/stations")
      .then(function (r) { return r.json(); })
      .then(function (stations) {
        stationSelectEl.innerHTML = "";
        if (stations.length === 0) {
          stationSelectEl.innerHTML = "<option value=\"\">No stations</option>";
          return;
        }
        stations.forEach(function (s) {
          var opt = document.createElement("option");
          opt.value = s.id;
          opt.textContent = s.name;
          stationSelectEl.appendChild(opt);
        });
      })
      .catch(function () {
        stationSelectEl.innerHTML = "<option value=\"\">Failed to load</option>";
      });
  }

  function appendNextChunk() {
    if (isAppending || chunkQueue.length === 0) return;
    if (!isSourceUsable() || sourceBuffer.updating) return;
    var chunk = chunkQueue.shift();
    if (!chunk) return;
    isAppending = true;
    try {
      sourceBuffer.appendBuffer(chunk.buffer);
    } catch (e) {
      isAppending = false;
      if (e.message && e.message.indexOf("removed from the parent") !== -1) {
        return;
      }
      log("Append error: " + e.message, "error");
    }
  }

  function ensureMSE() {
    if (!window.MediaSource) {
      setStatus("Browser doesn't support streaming", "failed");
      log("MediaSource Extensions not supported. Use Chrome, Firefox, or Safari.", "error");
      return false;
    }
    var mime = 'audio/webm; codecs="opus"';
    if (!MediaSource.isTypeSupported(mime)) {
      setStatus("Codec not supported", "failed");
      log("audio/webm; codecs=opus not supported in this browser.", "error");
      return false;
    }
    return true;
  }

  function connectSocket() {
    socket = new Phoenix.Socket("/socket", {});
    socket.onOpen(function () {
      log("WebSocket connected");
      setStatus("Joining channel...", "buffering");
    });
    socket.onError(function () {
      setStatus("Connection error", "failed");
    });
    socket.onClose(function () {
      if (mediaSource && mediaSource.readyState === "open") {
        setStatus("Reconnecting...", "reconnecting");
      } else if (statusDot.classList.contains("live") || statusDot.classList.contains("buffering")) {
        setStatus("Disconnected", "failed");
      }
    });

    var stationId = getSelectedStationId();
    if (!stationId) {
      setStatus("Select a station", "failed");
      log("Select a station from the dropdown", "error");
      playBtn.disabled = false;
      return;
    }
    channel = socket.channel("listener:" + stationId, {});
    channel.onClose(function () {
      setStatus("Channel closed", "failed");
    });
    channel.onError(function () {
      setStatus("Channel error", "failed");
    });

    socket.connect();

    channel
      .join()
      .receive("ok", function () {
        setStatus("Buffering...", "buffering");
        log("Joined – receiving audio (buffer catchup + live)");
      })
      .receive("error", function (resp) {
        setStatus("Failed to join", "failed");
        log("Join error: " + JSON.stringify(resp), "error");
        playBtn.disabled = false;
      });

    channel.on("audio", function (payload) {
      if (statusDot.classList.contains("reconnecting")) setStatus("Buffering...", "buffering");
      chunkCount++;
      chunksInLastSecond++;
      var seq = payload.sequence != null ? payload.sequence : chunkCount - 1;
      if (lastSequence >= 0 && seq > lastSequence + 1) {
        log("Gap in sequence: " + (lastSequence + 1) + ".." + (seq - 1), "warn");
      }
      lastSequence = seq;

      if (seq === 0 && isSourceUsable() && sourceBuffer.buffered.length > 0) {
        try {
          sourceBuffer.abort();
        } catch (_) {}
        chunkQueue = [];
        isAppending = false;
      }

      var binaryString = atob(payload.data);
      var bytes = new Uint8Array(binaryString.length);
      for (var i = 0; i < binaryString.length; i++) bytes[i] = binaryString.charCodeAt(i);

      chunkQueue.push({ buffer: bytes.buffer, sequence: seq });
      chunkQueue.sort(function (a, b) {
        return a.sequence - b.sequence;
      });
      if (chunkQueue.length > MAX_JITTER_QUEUE) {
        chunkQueue.splice(0, chunkQueue.length - MAX_JITTER_QUEUE);
      }
      appendNextChunk();
      updateStats();
    });
  }

  function startListening() {
    if (!ensureMSE()) return;
    if (mediaSource && mediaSource.readyState !== "closed") {
      try {
        if (mediaSource.readyState === "open" && mediaSource.sourceBuffers.length > 0) {
          mediaSource.sourceBuffers[0].abort();
        }
        mediaSource.endOfStream();
      } catch (_) {}
      mediaSource = null;
      sourceBuffer = null;
      chunkQueue = [];
      isAppending = false;
    }
    if (channel) channel.leave();
    if (socket) socket.disconnect();
    socket = null;
    channel = null;
    lastSequence = -1;
    chunksInLastSecond = 0;
    if (latencySampleIntervalId) {
      clearInterval(latencySampleIntervalId);
      latencySampleIntervalId = null;
    }
    sourceBufferErrorCount = 0;
    playBtn.disabled = true;
    setStatus("Opening stream...", "buffering");
    mediaSource = new MediaSource();
    audioPlayer.src = URL.createObjectURL(mediaSource);

    mediaSource.addEventListener("sourceopen", function () {
      log("MediaSource opened");
      sourceBuffer = mediaSource.addSourceBuffer('audio/webm; codecs="opus"');
      if (sourceBuffer.mode !== undefined) sourceBuffer.mode = "sequence";

      sourceBuffer.addEventListener("updateend", function () {
        isAppending = false;
        if (!isSourceUsable()) return;
        appendNextChunk();
        if (sourceBuffer.buffered.length > 0) {
          var bufSec = sourceBuffer.buffered.end(0) - audioPlayer.currentTime;
          if (audioPlayer.paused && bufSec >= START_BUFFER_SEC) {
            audioPlayer.play().catch(function (e) {
              log("Play error: " + e.message, "error");
            });
            setStatus("Live", "live");
          }
        }
      });

      sourceBuffer.addEventListener("error", function () {
        sourceBufferErrorCount++;
        if (sourceBufferErrorCount === 1) {
          log("Stream error (recovering…)", "warn");
        }
        if (!mediaSource || mediaSource.readyState !== "open" || !sourceBuffer) return;
        try {
          sourceBuffer.abort();
        } catch (_) {}
        isAppending = false;
        appendNextChunk();
      });

      setStatus("Connecting...", "buffering");
      connectSocket();
    });

    mediaSource.addEventListener("sourceended", function () {
      setStatus("Stream ended", "");
    });
    mediaSource.addEventListener("sourceclose", function () {});
  }

  function startLatencySampling() {
    if (latencySampleIntervalId) return;
    latencySampleIntervalId = setInterval(function () {
      var ms = estimateLatencyMs();
      latencyMsEl.textContent = ms != null ? ms + " ms" : "—";
    }, LATENCY_SAMPLE_INTERVAL_MS);
  }

  audioPlayer.addEventListener("playing", function () {
    setStatus("Live", "live");
    startLatencySampling();
  });

  setInterval(updateStats, 500);

  playBtn.addEventListener("click", function () {
    startListening();
  });

  if (stationSelectEl) loadStations();
})();
