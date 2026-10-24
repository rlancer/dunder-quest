// The brand kit's launch posts: a Copy button on each block. The buttons
// stay hidden without JavaScript or a clipboard, and the text can still be
// selected by hand.
(function () {
  if (!navigator.clipboard) return;
  document.querySelectorAll(".post .copy").forEach(function (button) {
    button.hidden = false;
    button.addEventListener("click", function () {
      const text = button.closest(".post").querySelector("code").textContent;
      navigator.clipboard.writeText(text).then(function () {
        button.textContent = "Copied";
        setTimeout(function () { button.textContent = "Copy"; }, 1500);
      });
    });
  });
})();
