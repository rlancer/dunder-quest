// The home page trailer starts as a plain link to YouTube with the thumbnail.
// Clicking it swaps in the privacy-enhanced player, so nobody downloads
// YouTube's scripts just for opening the page.
(function () {
  const link = document.querySelector("[data-yt]");
  if (!link) return;
  link.addEventListener("click", function (event) {
    if (event.ctrlKey || event.metaKey || event.shiftKey || event.button !== 0) return;
    event.preventDefault();
    const frame = document.createElement("iframe");
    frame.src = "https://www.youtube-nocookie.com/embed/" + link.dataset.yt + "?autoplay=1&rel=0";
    frame.title = "Dunder Quest trailer";
    frame.allow = "autoplay; encrypted-media; picture-in-picture; fullscreen";
    frame.allowFullscreen = true;
    link.replaceWith(Object.assign(document.createElement("div"), { className: "trailer" }));
    document.querySelector("#trailer .trailer").appendChild(frame);
  });
})();
