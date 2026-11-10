// The bot: plays all three levels through the real screens. It ships the
// first one untested, takes one wrong fix, and catches the other two with
// the level's own tool, then checks it ends on the takeaways.

import { cleanup, render, screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, expect, test } from "vitest";
import App from "./App";
import { LEVELS } from "./levels";

afterEach(cleanup);

test("the lab plays through", { timeout: 30000 }, async () => {
  const u = userEvent.setup();
  render(<App />);
  const tap = (name: string | RegExp) => u.click(screen.getByRole("button", { name }));
  const bookNonna = async () => {
    await u.click(screen.getAllByRole("button", { name: "Book" })[0]);
    await tap("Book for 2");
  };
  await tap("Start");

  // Level 1: ship it untested, and launch night goes badly.
  screen.getByText(LEVELS[0].brief);
  await tap("Ship it");
  screen.getByText("You shipped it.");
  screen.getByText(LEVELS[0].flaws.memory.why);
  // A wrong fix is built all the same, and only testing shows it's wrong.
  await tap(/have it keep track of them/);
  screen.getByText(LEVELS[0].flaws.server.rebuilt!);
  await bookNonna();
  await u.click(screen.getByRole("tab", { name: "Restaurant's tablet" }));
  screen.getByText("The restaurant's tablet shows the booking too.");
  await tap("Restart");
  screen.getByText("Restarted the server. Every booking was gone.");
  await tap("Tell Aleister");
  screen.getByText("You found it.");
  expect(screen.getByRole("button", { name: /have it keep track of them/ })).toHaveProperty("disabled", true);
  await tap(/save them in the database/);
  await bookNonna();
  await tap("Restart");
  screen.getByText("Restarted the server. Every booking was still there.");
  await tap("Ship it");
  screen.getByText("Shipped. Quiet night.");
  screen.getByText(/Launched broken once first\. 2 rebuilds\./);
  await tap("Next level");

  // Level 2: catch a booking in the air and change it.
  await tap("Got it");
  await u.click(screen.getByRole("checkbox"));
  await bookNonna();
  const caught = within(screen.getByRole("dialog", { name: "Message caught" }));
  await u.click(caught.getByRole("button", { name: "200" }));
  await u.click(caught.getByRole("button", { name: "Let it go" }));
  screen.getByText("Sent the server a party of 200. It said yes.");
  await tap("Tell Aleister");
  await tap(/Have the server check every booking/);
  await u.click(screen.getByRole("checkbox"));
  await bookNonna();
  await tap("200");
  await tap("Let it go");
  screen.getByText("Sent the server a party of 200. It refused.");
  await tap("Ship it");
  screen.getByText(/Caught before launch\. Fixed in one go\./);
  await tap("Next level");

  // Level 3: open the app up and find the key.
  await tap("Got it");
  await tap(/Somewhere quiet/);
  screen.getByText("Try The Gilded Radish.");
  await tap("Peek inside");
  await tap(/AI_KEY/);
  screen.getByText("Looked inside the app. The secret key is sitting in it.");
  await tap("Done");
  await tap("Tell Aleister");
  await tap(/Keep the key on the server/);
  await tap("Peek inside");
  screen.getByText("Looked inside the app. No secrets in it.");
  await tap("Done");
  await tap("Ship it");
  await tap("Finish");

  screen.getByText("Forkcast is live.");
  screen.getByText(/You caught 2 of 3 before launch/);
  for (const level of LEVELS) screen.getByText(level.win.prompt);
});
