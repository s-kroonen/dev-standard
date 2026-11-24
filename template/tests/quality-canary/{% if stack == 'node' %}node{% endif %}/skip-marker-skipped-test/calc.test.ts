import { expect, test } from "vitest";
import { add } from "./calc";

test.skip("add", () => {
  expect(add(2, 3)).toBe(6);
});
