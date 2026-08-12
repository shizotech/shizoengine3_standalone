# Skill: Generate HTML Run Reports

## Objective
After each execution/run, generate a detailed, modern, self-contained `.html` report summarizing the run.

The report must:
- Be visually clean and consistent across runs
- Capture key technical details, outputs, and artifacts
- Allow flexible inclusion of dynamic content (charts, logs, tables, JSON, etc.)
- Be fully standalone (no external dependencies unless explicitly justified)

---

## Output Requirements

- File name format:
  `reports/<date>/run_report_<timestamp>.html`
  example:  `reports/30_01_2026/run_report_22_00.html` to create a report on the 30. of January 2026 at 22:00

- Must include:
  - Run metadata (time, duration, task, status)
  - Summary (high-level explanation of what happened)
  - Steps / execution trace
  - Outputs (files, logs, results)
  - Errors or warnings (if any)
  - Optional: charts, metrics, or visualizations
  - Optional: raw data / JSON blocks

---

## Styling & UX Guidelines

- Use modern UI styling (clean spacing, subtle shadows, rounded corners)
- Prefer system fonts or safe modern font stack
- Use color coding:
  - Green → success
  - Yellow → warnings
  - Red → errors
- Sections should be collapsible where useful
- Code/logs must be monospaced and scrollable
- Keep layout consistent across reports

---

## Flexibility Rules

You are encouraged to:
- Add charts (e.g. Chart.js, inline SVG, or simple HTML graphs)
- Include tables for structured data
- Embed JSON viewers or formatted blocks
- Highlight important metrics

Do NOT:
- Break the overall layout structure
- Remove required sections
- Introduce heavy external dependencies unless necessary

---

## Data Population

You must infer and populate:
- Meaningful summaries (not just raw logs)
- Key metrics (duration, counts, sizes, etc.)
- Important highlights (failures, anomalies, decisions)

---

## File Structure

Use the provided HTML template as a base.
Fill in placeholders and extend sections where useful.

---

## Quality Bar

The report should:
- Be readable by a human without context
- Feel like a professional engineering report
- Help debug or understand the run quickly

Avoid dumping raw data without structure.


# Base HTML Template

Use this HTML template for your report:

```
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Run Report</title>

  <style>
    :root {
      --bg: #0f172a;
      --card: #111827;
      --text: #e5e7eb;
      --muted: #9ca3af;
      --accent: #3b82f6;
      --success: #10b981;
      --warning: #f59e0b;
      --error: #ef4444;
    }

    body {
      margin: 0;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      background: var(--bg);
      color: var(--text);
    }

    .container {
      max-width: 1100px;
      margin: 40px auto;
      padding: 20px;
    }

    h1, h2, h3 {
      margin-bottom: 10px;
    }

    .card {
      background: var(--card);
      padding: 20px;
      border-radius: 12px;
      margin-bottom: 20px;
      box-shadow: 0 4px 20px rgba(0,0,0,0.3);
    }

    .meta {
      display: flex;
      flex-wrap: wrap;
      gap: 20px;
      font-size: 14px;
      color: var(--muted);
    }

    .badge {
      padding: 4px 10px;
      border-radius: 999px;
      font-size: 12px;
      font-weight: 600;
    }

    .success { background: rgba(16,185,129,0.2); color: var(--success); }
    .warning { background: rgba(245,158,11,0.2); color: var(--warning); }
    .error   { background: rgba(239,68,68,0.2); color: var(--error); }

    pre {
      background: #020617;
      padding: 15px;
      border-radius: 8px;
      overflow-x: auto;
      font-size: 13px;
    }

    code {
      font-family: "SFMono-Regular", Consolas, monospace;
    }

    .section-header {
      display: flex;
      justify-content: space-between;
      cursor: pointer;
    }

    .collapsible {
      display: none;
      margin-top: 10px;
    }

    .table {
      width: 100%;
      border-collapse: collapse;
    }

    .table th, .table td {
      padding: 10px;
      border-bottom: 1px solid #1f2937;
      text-align: left;
    }

  </style>
</head>

<body>
  <div class="container">

    <!-- HEADER -->
    <div class="card">
      <h1>Run Report</h1>
      <div class="meta">
        <div><strong>Run ID:</strong> {{RUN_ID}}</div>
        <div><strong>Timestamp:</strong> {{TIMESTAMP}}</div>
        <div><strong>Duration:</strong> {{DURATION}}</div>
        <div><strong>Status:</strong> 
          <span class="badge {{STATUS_CLASS}}">{{STATUS}}</span>
        </div>
      </div>
    </div>

    <!-- SUMMARY -->
    <div class="card">
      <h2>Summary</h2>
      <p>{{SUMMARY}}</p>
    </div>

    <!-- STEPS -->
    <div class="card">
      <div class="section-header" onclick="toggle(this)">
        <h2>Execution Steps</h2>
      </div>
      <div class="collapsible">
        {{STEPS_CONTENT}}
      </div>
    </div>

    <!-- OUTPUTS -->
    <div class="card">
      <div class="section-header" onclick="toggle(this)">
        <h2>Outputs</h2>
      </div>
      <div class="collapsible">
        {{OUTPUTS_CONTENT}}
      </div>
    </div>

    <!-- ERRORS -->
    <div class="card">
      <div class="section-header" onclick="toggle(this)">
        <h2>Errors & Warnings</h2>
      </div>
      <div class="collapsible">
        {{ERRORS_CONTENT}}
      </div>
    </div>

    <!-- METRICS -->
    <div class="card">
      <h2>Metrics</h2>
      {{METRICS_TABLE}}
    </div>

    <!-- OPTIONAL VISUALS -->
    <div class="card">
      <h2>Visualizations</h2>
      {{VISUALS}}
    </div>

  </div>

  <script>
    function toggle(el) {
      const content = el.nextElementSibling;
      content.style.display = content.style.display === "block" ? "none" : "block";
    }
  </script>

</body>
</html>
```