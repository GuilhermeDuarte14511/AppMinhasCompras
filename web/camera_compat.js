(function () {
  "use strict";

  const configuredVideos = new WeakSet();

  function prepareVideo(video) {
    if (!(video instanceof HTMLVideoElement)) {
      return;
    }

    video.setAttribute("playsinline", "");
    video.setAttribute("webkit-playsinline", "");
    video.setAttribute("autoplay", "");
    video.setAttribute("muted", "");
    video.playsInline = true;
    video.autoplay = true;
    video.muted = true;

    if (configuredVideos.has(video) && !video.paused) {
      return;
    }
    configuredVideos.add(video);

    if (video.srcObject) {
      const playback = video.play();
      if (playback && typeof playback.catch === "function") {
        playback.catch(function () {
          // The Flutter scanner reports actionable camera errors itself.
        });
      }
    }
  }

  function prepareVideos(root) {
    if (!root) {
      return;
    }

    if (root instanceof HTMLVideoElement) {
      prepareVideo(root);
    }

    if (typeof root.querySelectorAll === "function") {
      root.querySelectorAll("video").forEach(prepareVideo);
    }
  }

  const observer = new MutationObserver(function (mutations) {
    mutations.forEach(function (mutation) {
      mutation.addedNodes.forEach(prepareVideos);
    });
  });

  observer.observe(document.documentElement, {
    childList: true,
    subtree: true,
  });

  window.shoppingCameraCompat = {
    prepare: function () {
      prepareVideos(document);
    },
  };

  document.addEventListener("visibilitychange", function () {
    if (!document.hidden) {
      prepareVideos(document);
    }
  });

  window.addEventListener("pageshow", function () {
    prepareVideos(document);
  });
})();
