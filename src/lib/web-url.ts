import { z } from "zod";

/** A web link a person typed or a page supplied. Other schemes (file:, sms:, javascript:) are refused. */
export const webUrl = z
  .string()
  .max(2048)
  .url()
  .refine((value) => /^https?:\/\//i.test(value), "Only http and https links are supported.");
