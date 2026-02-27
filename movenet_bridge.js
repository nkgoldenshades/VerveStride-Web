(function () {
  const BRIDGE_NAME = 'movenetBridge';

  const TFJS_URL = 'https://cdn.jsdelivr.net/npm/@tensorflow/tfjs@4.20.0/dist/tf.min.js';
  const POSE_DET_URL = 'https://cdn.jsdelivr.net/npm/@tensorflow-models/pose-detection@2.1.3/dist/pose-detection.min.js';

  let _tfjsLoadPromise = null;

  function loadScriptOnce(url) {
    const existing = document.querySelector(`script[src="${url}"]`);
    if (existing) return Promise.resolve();

    return new Promise((resolve, reject) => {
      const s = document.createElement('script');
      s.src = url;
      s.async = true;
      s.onload = () => resolve();
      s.onerror = () => reject(new Error(`Failed to load ${url}`));
      document.head.appendChild(s);
    });
  }

  function nowMs() {
    return (typeof performance !== 'undefined' && performance.now)
      ? performance.now()
      : Date.now();
  }

  function clamp(v, min, max) {
    return Math.min(max, Math.max(min, v));
  }

  function drawKeypoints(ctx, keypoints) {
    ctx.fillStyle = 'rgba(25, 227, 214, 0.9)';
    for (const k of keypoints) {
      const s = k.score ?? 0;
      if (s < 0.25) continue;
      ctx.beginPath();
      ctx.arc(k.x, k.y, 4, 0, Math.PI * 2);
      ctx.fill();
    }
  }

  const EDGES = [
    [5, 7], [7, 9],
    [6, 8], [8, 10],
    [5, 6],
    [5, 11], [6, 12],
    [11, 12],
    [11, 13], [13, 15],
    [12, 14], [14, 16]
  ];

  function drawSkeleton(ctx, keypoints) {
    ctx.strokeStyle = 'rgba(124, 92, 255, 0.9)';
    ctx.lineWidth = 3;

    for (const [a, b] of EDGES) {
      const ka = keypoints[a];
      const kb = keypoints[b];
      if (!ka || !kb) continue;
      if ((ka.score ?? 0) < 0.25 || (kb.score ?? 0) < 0.25) continue;
      ctx.beginPath();
      ctx.moveTo(ka.x, ka.y);
      ctx.lineTo(kb.x, kb.y);
      ctx.stroke();
    }
  }

  async function ensureTfjsLoaded() {
    if (_tfjsLoadPromise) {
      await _tfjsLoadPromise;
    } else {
      _tfjsLoadPromise = (async () => {
        if (!window.tf) {
          await loadScriptOnce(TFJS_URL);
        }
        if (!window.poseDetection) {
          await loadScriptOnce(POSE_DET_URL);
        }
      })();

      await _tfjsLoadPromise;
    }

    if (!window.tf) throw new Error('TFJS not loaded');
    if (!window.poseDetection) throw new Error('pose-detection not loaded');
    if (window.tf && window.tf.ready) {
      await window.tf.ready();
    }
  }

  async function createDetector() {
    await ensureTfjsLoaded();
    if (window.poseDetection && window.poseDetection.createDetector) {
      const model = window.poseDetection.SupportedModels.MoveNet;
      const detector = await window.poseDetection.createDetector(model, {
        modelType: window.poseDetection.movenet.modelType.SINGLEPOSE_LIGHTNING,
        enableSmoothing: true,
      });
      return detector;
    }
    throw new Error('poseDetection.createDetector missing');
  }

  const state = {
    started: false,
    initializing: false,
    initPromise: null,
    overlayEnabled: true,
    status: 'idle',
    lastError: null,
    containerId: null,
    video: null,
    canvas: null,
    ctx: null,
    detector: null,
    raf: null,
    lastTs: 0,
    fps: 0,
    keypointCallback: null,
  };

  async function init(containerId) {
    if (state.started) {
      state.status = 'running';
      return;
    }
    if (state.initializing && state.initPromise) {
      return state.initPromise;
    }

    state.initializing = true;
    state.initPromise = (async () => {
      state.containerId = containerId;
      const container = document.getElementById(containerId);
      if (!container) throw new Error('container not found');

      container.style.position = 'relative';
      container.style.background = 'black';
      container.style.overflow = 'hidden';

      const video = document.createElement('video');
      video.autoplay = true;
      video.playsInline = true;
      video.muted = true;
      video.style.width = '100%';
      video.style.height = '100%';
      // Use contain so the full camera frame is visible (no crop), even in wide containers.
      video.style.objectFit = 'contain';

      const canvas = document.createElement('canvas');
      canvas.style.position = 'absolute';
      canvas.style.left = '0';
      canvas.style.top = '0';
      canvas.style.width = '100%';
      canvas.style.height = '100%';
      canvas.style.pointerEvents = 'none';

      container.innerHTML = '';
      container.appendChild(video);
      container.appendChild(canvas);

      state.video = video;
      state.canvas = canvas;
      state.ctx = canvas.getContext('2d');

      state.status = 'requesting_camera';

      let stream;
      try {
        stream = await navigator.mediaDevices.getUserMedia({
          video: {
            facingMode: 'user',
            width: { ideal: 640 },
            height: { ideal: 480 },
          },
          audio: false,
        });
      } catch (error) {
        if (error.name === 'NotAllowedError') {
          throw new Error('Camera permission denied. Please allow camera access in your browser settings.');
        } else if (error.name === 'NotFoundError') {
          throw new Error('No camera found. Please connect a camera and try again.');
        } else if (error.name === 'NotReadableError') {
          throw new Error('Camera is already in use by another application.');
        } else {
          throw new Error(`Camera access failed: ${error.message}`);
        }
      }

      video.srcObject = stream;

      await new Promise((resolve) => {
        video.onloadedmetadata = () => resolve();
      });

      state.status = 'loading_model';
      state.detector = await createDetector();

      state.started = true;
      state.initializing = false;
      state.status = 'running';

      const loop = async (ts) => {
        if (!state.started) return;
        state.raf = requestAnimationFrame(loop);

        const dt = ts - (state.lastTs || ts);
        state.lastTs = ts;
        if (dt > 0) {
          const instFps = 1000 / dt;
          state.fps = clamp(state.fps * 0.9 + instFps * 0.1, 0, 120);
        }

        const vw = video.videoWidth || 640;
        const vh = video.videoHeight || 480;

        const cw = container.clientWidth || vw;
        const ch = container.clientHeight || vh;

        // Canvas uses container pixels; poses are in video pixels.
        canvas.width = cw;
        canvas.height = ch;

        if (!state.overlayEnabled) {
          state.ctx.clearRect(0, 0, cw, ch);
          return;
        }

        try {
          const poses = await state.detector.estimatePoses(video, {
            maxPoses: 1,
            flipHorizontal: true,
          });

          state.ctx.clearRect(0, 0, cw, ch);

          if (poses && poses.length) {
            const kp = poses[0].keypoints || [];

            // Send keypoints to Flutter if callback is registered
            if (state.keypointCallback && typeof state.keypointCallback === 'function') {
              try {
                // Send normalized keypoints (0.0-1.0 range)
                const normalizedKp = kp.map((k, idx) => ({
                  index: idx,
                  x: (k.x ?? 0) / vw,
                  y: (k.y ?? 0) / vh,
                  confidence: k.score ?? 0,
                }));
                state.keypointCallback(normalizedKp);
              } catch (cbError) {
                // Don't break rendering if callback fails
                console.warn('Keypoint callback error:', cbError);
              }
            }

            // Match the same contain scaling used by the <video>.
            const scale = Math.min(cw / vw, ch / vh);
            const dx = (cw - vw * scale) / 2;
            const dy = (ch - vh * scale) / 2;
            const kp2 = kp.map((k) => ({
              ...k,
              x: (k.x ?? 0) * scale + dx,
              y: (k.y ?? 0) * scale + dy,
            }));

            drawSkeleton(state.ctx, kp2);
            drawKeypoints(state.ctx, kp2);
          }
        } catch (e) {
          state.lastError = String(e);
        }
      };

      state.raf = requestAnimationFrame(loop);
    })().catch((e) => {
      state.lastError = String(e);
      state.status = 'error';
      state.started = false;
      state.initializing = false;
      throw e;
    });

    return state.initPromise;
  }

  function setOverlayEnabled(enabled) {
    state.overlayEnabled = !!enabled;
  }

  function getStatus() {
    return {
      status: state.status,
      lastError: state.lastError,
      fps: state.fps,
    };
  }

  function stop() {
    state.started = false;
    state.status = 'stopped';
    if (state.raf) cancelAnimationFrame(state.raf);
    state.raf = null;
    if (state.detector && state.detector.dispose) {
      try { state.detector.dispose(); } catch (_) { }
    }
    state.detector = null;
    if (state.video && state.video.srcObject) {
      const tracks = state.video.srcObject.getTracks ? state.video.srcObject.getTracks() : [];
      for (const t of tracks) {
        try { t.stop(); } catch (_) { }
      }
    }
  }

  function setKeypointCallback(callback) {
    state.keypointCallback = callback;
  }

  async function requestCameraPermission() {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: 'user' },
        audio: false,
      });
      // Immediately stop the stream since we're just checking permission
      stream.getTracks().forEach(track => track.stop());
      return { success: true, message: 'Camera permission granted' };
    } catch (error) {
      if (error.name === 'NotAllowedError') {
        return { success: false, message: 'Camera permission denied. Please allow camera access.' };
      } else if (error.name === 'NotFoundError') {
        return { success: false, message: 'No camera found.' };
      } else {
        return { success: false, message: `Camera error: ${error.message}` };
      }
    }
  }

  window[BRIDGE_NAME] = {
    init,
    stop,
    setOverlayEnabled,
    getStatus,
    setKeypointCallback,
    requestCameraPermission,
  };
})();
