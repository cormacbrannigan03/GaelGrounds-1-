import { supabase } from './supabaseClient'

const PAGE_SIZE = 1000

// PostgREST (Supabase's data API) caps any single request at 1000 rows by
// default -- an unbounded .select() silently truncates rather than erroring,
// so a plain query only ever returns however many rows happen to be within
// the first page, which is not necessarily the most recent ones (no implicit
// ordering) and gets worse as any table grows past 1000 rows. This fetches
// every page needed to cover the full table.
//
// A cheap `head: true` count tells us the page count upfront, so every page
// can be requested in parallel via Promise.all instead of one at a time --
// total wall-clock time then depends on the slowest single round trip
// rather than the sum of all of them.
export async function fetchAllRows<T>(
  table: string,
  select: string,
  configure?: (q: any) => any,
): Promise<T[]> {
  let countQuery = supabase.from(table as any).select(select, { count: 'exact', head: true })
  if (configure) countQuery = configure(countQuery)
  const { count } = await countQuery
  const total = count ?? 0
  if (total === 0) return []

  const pageCount = Math.ceil(total / PAGE_SIZE)
  const pages = await Promise.all(
    Array.from({ length: pageCount }, (_, i) => {
      let query = supabase.from(table as any).select(select)
      if (configure) query = configure(query)
      const from = i * PAGE_SIZE
      return query.range(from, from + PAGE_SIZE - 1)
    }),
  )

  const rows: T[] = []
  for (const { data } of pages) {
    if (data) rows.push(...(data as T[]))
  }
  return rows
}
