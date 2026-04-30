# SCORE Calculator — Algorithm & Methodology Overview

**For:** Gallup Partnership Team (Anna Siebert, Jamie Hunt, Brent Michels, Jordan Warnock, Dean Jones)
**Prepared by:** Silent Partners
**Date:** May 2026

---

## What the SCORE Calculator Does

The SCORE Calculator measures the severity of a specific friction point across five business dimensions and produces a single **0–100 score** that tells an executive not just that something hurts, but *how much* and *where*. Participants score each friction point they identify during the workshop, and the result updates in real time as they answer ten questions.

The score is calibrated before a single question is asked — by the client's **industry** and their current **strategic priority**. The same friction point at a manufacturing company focused on cost reduction will score differently than at a SaaS company focused on revenue growth, because the weights shift to match what actually matters to that business.

---

## Step 1: Industry Selection

The client selects their industry from six presets. Each preset assigns a weight (out of 100) to each of the five SCORE dimensions — reflecting where friction costs most in that sector.

| Industry | S — Speed | C — Cost | O — Operations | R — Risk | E — Earnings |
|---|---|---|---|---|---|
| Technology / SaaS | 25 | 15 | 15 | 15 | **30** |
| Healthcare | 15 | 20 | 20 | **30** | 15 |
| Financial Services | 20 | 20 | 15 | **30** | 15 |
| Manufacturing | 15 | **25** | **30** | 15 | 15 |
| Professional Services | **25** | 20 | 20 | 10 | 25 |
| Retail / Consumer | 20 | 20 | 15 | 15 | **30** |

---

## Step 2: Priority Focus

The client selects their current strategic priority. This applies a ± adjustment to each dimension's weight, sharpening the score toward the problems that are actually costing the business most right now.

| Priority | S | C | O | R | E |
|---|---|---|---|---|---|
| Revenue Growth | +3 | −2 | −4 | −2 | **+5** |
| Cost Reduction | −2 | **+5** | +3 | −2 | −4 |
| Speed to Market | **+5** | −2 | −4 | −2 | +3 |
| Operational Efficiency | −2 | +3 | **+5** | −2 | −4 |
| Risk / Compliance | −2 | −2 | +3 | **+5** | −4 |

The final weight for each dimension = industry weight + priority adjustment.

---

## The Ten Questions

Two questions per dimension. Each is answered on a 1–5 scale — **1 is the least severe, 5 is the most severe**. The severity labels are shown on screen so participants anchor to a description, not an abstract number.

### S — Speed

**Q1. How much slower is this process than it should be?**
1. On pace — roughly where it should be, minor delays occasionally
2. Noticeably slow — takes about 2× longer than it should
3. Significantly slow — takes 3–5× longer, creates visible bottlenecks
4. Severely slow — takes 5–10× longer, routinely blocks other work
5. Completely broken — 10× slower, everybody knows it, nobody can fix it

**Q2. How much of your team's time gets consumed by this?**
1. Minimal — a few hours per week across the whole team
2. Noticeable — equivalent of a part-time person dedicated to it
3. Substantial — one or more full-time equivalents trapped in it
4. Heavy — multiple people spending the majority of their time on this
5. Massive — an entire team or function consumed by this process

---

### C — Cost

**Q3. How much of your department's budget does this friction consume?**
1. Negligible — less than 5% of the relevant budget
2. Moderate — around 5–10% of the budget, worth watching
3. Significant — 10–20% of the budget, hard to ignore
4. Major — 20–35% of the budget, one of the biggest line items
5. Dominant — 35%+ of the budget, it defines the department spend

**Q4. How does your cost compare to what a well-run version should cost?**
1. Close to reasonable — maybe 10–20% more than expected
2. Somewhat high — about 1.5–2× what it should cost
3. Clearly excessive — about 2–3× what a well-run operation would pay
4. Badly inflated — 3–5× higher than it should be
5. Out of control — 5× the cost of a well-run equivalent

---

### O — Operational Efficiency

**Q5. How often does work have to be redone or corrected?**
1. Rarely — under 5% of output needs rework, normal operations
2. Sometimes — 5–10% needs rework, occasional corrections
3. Frequently — 10–20% needs rework, it is a known problem
4. Constantly — 20–35% needs rework, a significant drag on throughput
5. More often than not — 35%+, the team expects things to be wrong the first time

**Q6. How consistent is the quality across your team?**
1. Very consistent — everyone delivers roughly the same standard
2. Mostly consistent — some variation but generally acceptable range
3. Inconsistent — depends on who does it, noticeable quality gaps
4. Highly variable — dramatic difference between best and worst performers
5. Unpredictable — output quality is essentially random, no standard exists

---

### R — Risk

**Q7. If this process fails badly, how severe is the impact?**
1. Inconvenient — recoverable within days, no external impact
2. Disruptive — takes weeks to recover, some customer or partner impact
3. Damaging — significant financial loss or customer impact
4. Severe — major regulatory, financial, or reputational exposure
5. Existential — could threaten the business, regulatory shutdown or catastrophic loss

**Q8. How concentrated is the knowledge? How many people could this fall apart without?**
1. Well distributed — team is cross-trained, no single points of failure
2. Slightly concentrated — 3–4 people carry most of the knowledge
3. Concentrated — 2–3 key people, losing one would cause real disruption
4. Highly concentrated — 1–2 people, if they leave, serious trouble
5. Single point of failure — one person, if they are gone tomorrow, it stops

---

### E — Earnings

**Q9. How much revenue or growth is being constrained by this friction?**
1. Not limiting revenue — this friction exists but is not capping growth
2. Slight constraint — some missed opportunities, maybe a few percent of potential
3. Meaningful constraint — clearly leaving money on the table, team talks about it
4. Major constraint — directly limiting ability to close deals or serve customers
5. Growth ceiling — this is the bottleneck, cannot grow past it without solving it

**Q10. If you solved this tomorrow, how much new capacity or revenue would it unlock?**
1. Marginal improvement — nice to have but would not change trajectory
2. Noticeable improvement — would free up meaningful capacity or unlock some revenue
3. Significant unlock — would visibly improve growth rate or capacity
4. Major unlock — would open a new tier of performance for the business
5. Transformational — would fundamentally change what the business is capable of

---

## How the Score Is Calculated

For each friction point:

```
For each dimension (S, C, O, R, E):
  dimension_score = ((Q_avg - 1) / 4) × adjusted_weight

Where:
  Q_avg          = average of the two question answers (1–5 scale)
  adjusted_weight = industry_weight + priority_adjustment
  (Q_avg - 1) / 4 normalizes the answer to 0.0–1.0

Total SCORE = sum of all five dimension scores → result is 0–100
```

**Example:** A Tech/SaaS company focused on Revenue Growth rates a friction point with Q1=4, Q2=3 (Speed avg=3.5). Adjusted Speed weight = 25+3 = 28. Speed contribution = ((3.5−1)/4) × 28 = 0.625 × 28 = **17.5 points** out of a possible 28.

Partially answered friction points are excluded from the total — incomplete dimensions don't inflate or deflate the score.

---

## Severity Bands

| Score | Rating |
|---|---|
| 0–19 | Minimal Friction |
| 20–39 | Low Opportunity |
| 40–59 | Moderate Opportunity |
| 60–79 | High Opportunity |
| 80–100 | **Critical Opportunity** |

---

## What the Output Shows

For each friction point, participants see:

- Score contribution from each of the five SCORE dimensions
- **Total SCORE** (0–100)
- **Severity band** (Minimal → Critical Opportunity)
- **Primary Driver** — which dimension accounts for the largest share of the total
- The score updates in real time as each question is answered

An important design principle: the score surfaces where to look, not what to decide. In the April 2026 McGregor Metal workshop, one item scored highest but the team immediately recognized it as a nuisance rather than a company-wide priority. The facilitator's framing: *"This is why you have to have human judgment and taste in this conversation — if you simply outsource the decision, you lose the nuance of actually understanding the process."* The score is the input to the conversation, not the conclusion.

---

## Connection to Gallup's Work

SCORE measures the **operational cost** of friction — what it is doing to speed, cost, quality, risk, and earnings potential. Gallup's Q12 measures the **human cost** — what that friction is doing to the conditions people need to do their best work.

Used together, the two instruments triangulate the same problem from opposite directions:

- **Gallup Q12** → where engagement is breaking down and the human conditions that explain it
- **SCORE** → what that breakdown costs in operational terms, and which friction points to prioritize fixing first

The Earnings (E) dimension is the most natural bridge: it asks directly whether friction is capping growth, which converts a people-level problem into the language that drives executive action.

---

*Source: Silent Partners `sp-workshop-v2` — `score-v2-constants.ts`, `friction-score-calculator.tsx`*
