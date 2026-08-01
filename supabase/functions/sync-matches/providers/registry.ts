import type { MatchDataProvider } from "../shared/types.ts";
import { scorebeoProvider } from "./scorebeo.ts";
import { clubzapProvider } from "./clubzap.ts";
import { csvProvider } from "./csv.ts";
import { manualProvider } from "./manual.ts";

// The one place in the whole system that lists concrete providers. Adding a
// new source (a future API, another CSV format, whatever) is: write a file
// implementing MatchDataProvider next to these, add it here, add a row to
// `data_providers`. index.ts, normalize.ts, and the app never change.
export const providerRegistry: Record<string, MatchDataProvider> = {
  scorebeo: scorebeoProvider,
  clubzap: clubzapProvider,
  csv: csvProvider,
  manual: manualProvider,
};
