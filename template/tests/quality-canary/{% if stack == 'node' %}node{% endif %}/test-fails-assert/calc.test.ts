import { expect, test } from "vitest";
import { add } from "./calc";

test("add", () => {
  expect(add(2, 3)).toBe(6);
});
