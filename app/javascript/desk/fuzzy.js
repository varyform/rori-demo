// The one fuzzy matcher behind ⌘K and the terminal.
//
// Subsequence match: every query character must appear in order. Consecutive
// runs and word starts score higher; shorter labels win ties. Spaces and
// dashes in the query are separators ("cover-bars" matches "Cover bars").
// Known to be naive — it's shared precisely so it can be improved in one place.
export function score(text, query) {
  query = query.trim().toLowerCase()
  if (!query) return 1
  text = text.toLowerCase()

  let total = 0
  let from = 0
  let previous = -2
  for (const char of query) {
    if (char === " " || char === "-") continue
    const at = text.indexOf(char, from)
    if (at < 0) return 0
    total += 1
    if (at === previous + 1) total += 3
    if (at === 0 || " /-_".includes(text[at - 1])) total += 2
    previous = at
    from = at + 1
  }
  return total - text.length / 100
}
