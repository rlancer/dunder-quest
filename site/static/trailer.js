// Each trailer starts as a plain link to YouTube with the thumbnail.
// Clicking it swaps in the privacy-enhanced player, so nobody downloads
// YouTube's scripts just for opening the page.
(function () {
  document.querySelectorAll("[data-yt]").forEach(function (link) {
    link.addEventListener("click", function (event) {
      if (event.ctrlKey || event.metaKey || event.shiftKey || event.button !== 0) return;
      event.preventDefault();
      const frame = document.createElement("iframe");
      frame.src = "https://www.youtube-nocookie.com/embed/" + link.dataset.yt + "?autoplay=1&rel=0";
      const label = link.querySelector(".sr");
      frame.title = label ? label.textContent.replace(/^Play the /, "") : "Trailer";
      frame.allow = "autoplay; encrypted-media; picture-in-picture; fullscreen";
      frame.allowFullscreen = true;
      const box = Object.assign(document.createElement("div"), { className: "trailer" });
      box.appendChild(frame);
      link.replaceWith(box);
    });
  });
})();
