// The one fuzzy matcher behind ⌘K and the terminal.
//
// Every query character must appear in order (spaces and dashes in the query
// are ignored, so "cover-menu" and "cover menu" match "Cover menu bar"). Among all
// ways to place them, it keeps the best-scoring one: characters at word starts
// — including each "›" segment of a path — and consecutive runs score high,
// gaps cost a little. That's what lets "uthen" find "UI › Theme › Nord":
// u, the and n each start a segment.
const SEPARATORS = " ›/-_.:…"
const BOUNDARY = 8      // character starts a word or segment
const FIRST = 4         // …and it's the very first character
const CONSECUTIVE = 5   // follows the previous match directly
const GAP_OPEN = 3      // cost of skipping ahead…
const GAP_EXTEND = 1    // …plus this per extra skipped character

export function score(text, query) {
  query = query.toLowerCase().replace(/[\s-]+/g, "")
  if (!query) return 1
  text = text.toLowerCase()
  const n = text.length
  const m = query.length
  if (m > n) return 0

  const boundary = (i) => i === 0 || SEPARATORS.includes(text[i - 1])
  // previous[i]: best score with query[j - 1] placed at text[i].
  let previous = new Array(n).fill(-Infinity)

  for (let j = 0; j < m; j++) {
    const current = new Array(n).fill(-Infinity)
    let gapped = -Infinity // best previous[k] for k <= i - 2, minus its gap cost to i

    for (let i = 0; i < n; i++) {
      if (j > 0 && i >= 2) gapped = Math.max(gapped - GAP_EXTEND, previous[i - 2] - GAP_OPEN)
      if (text[i] !== query[j]) continue

      const bonus = 1 + (boundary(i) ? BOUNDARY : 0)
      if (j === 0) {
        current[i] = bonus + (i === 0 ? FIRST : 0) - i * 0.05
      } else {
        const direct = i >= 1 ? previous[i - 1] + CONSECUTIVE : -Infinity
        current[i] = Math.max(direct, gapped) + bonus
      }
    }
    previous = current
  }

  const best = Math.max(...previous)
  // Shorter texts win ties; a match always stays above zero.
  return best === -Infinity ? 0 : Math.max(best - n * 0.01, 0.001)
}
