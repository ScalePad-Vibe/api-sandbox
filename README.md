# ScalePad API Sandbox

An interactive PowerShell recipe that walks you through the ScalePad **Core** and **Lifecycle Manager** APIs. Create initiatives with budgets, schedule meetings, and explore your client data -- all from an in-terminal menu.

## What You'll Learn

- Authenticating with the ScalePad API using `x-api-key`
- Listing clients from the **Core API**
- Creating, listing, and deleting **Initiatives** with one-time and recurring budgets
- Scheduling **Meetings** with ProseMirror-formatted agendas
- Chaining multiple API calls (create an initiative, then PUT its budget and recurring investments)

## Prerequisites

| Requirement | Details |
|-------------|---------|
| **PowerShell** | 5.1+ (Windows) or PowerShell 7+ (macOS / Linux) |
| **API Key** | Generate one from your ScalePad account under **Settings > API** |
| **Network** | HTTPS access to `api.scalepad.com` |

## Quick Start

**1. Clone this repository**

```bash
git clone https://github.com/ScalePad-Vibe/api-sandbox.git
cd api-sandbox
```

**2. Run the script**

```powershell
# Windows PowerShell
powershell -ExecutionPolicy Bypass -File .\ScalePad-Sandbox.ps1

# PowerShell 7 (cross-platform)
pwsh -ExecutionPolicy Bypass -File ./ScalePad-Sandbox.ps1
```

**3. Enter your API key when prompted.** The key is stored in memory for the current session only -- it is never written to disk.

## API Endpoints Used

### Core API

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/core/v1/clients` | List all client organizations |

### Lifecycle Manager API

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/lifecycle-manager/v1/initiatives` | List all initiatives |
| `POST` | `/lifecycle-manager/v1/initiatives` | Create a new initiative |
| `PUT` | `/lifecycle-manager/v1/initiatives/{id}/budget` | Set one-time budget line items |
| `PUT` | `/lifecycle-manager/v1/initiatives/{id}/recurring` | Set recurring investment line items |
| `DELETE` | `/lifecycle-manager/v1/initiatives/{id}` | Delete an initiative |
| `GET` | `/lifecycle-manager/v1/meetings` | List all meetings |
| `POST` | `/lifecycle-manager/v2/meetings` | Schedule a new meeting |

> **Note:** This recipe fetches the first page of results and does not follow `next_cursor` pagination. For accounts with large datasets, you may want to extend the fetcher functions.

## Interactive Menu

```
  +------------------------------------------------------+
  | ScalePad API Sandbox                                  |
  +------------------------------------------------------+

  +----------------------------------------------------------+
  | MAIN MENU                                                |
  +----------------------------------------------------------+
  | Explore the ScalePad API interactively.                  |
  |                                                          |
  | 1. Clients                                               |
  | 2. Initiatives                                           |
  | 3. Meetings                                              |
  | 4. Exit                                                  |
  +----------------------------------------------------------+
```

### Clients

- **List** -- Fetches all clients and displays their ID, name, and lifecycle status.

### Initiatives

- **List** -- Shows every initiative grouped by client, including current status.
- **Create** -- Pick a client (or all clients) and one of five sample initiatives. Optionally applies one-time budget and monthly recurring line items via separate `PUT` calls.
- **Delete** -- Search by name with partial matching, review matches, then selectively delete one, several, or all.

### Meetings

- **List** -- Shows all meetings with client name, title, and scheduled time.
- **Create** -- Pick a client (or all clients) and one of five sample meetings. Each meeting is created with a title, schedule (7 days from now), and a ProseMirror-formatted agenda.

## Sample Data

The sandbox includes ready-to-use templates so you can create realistic data with a few keystrokes.

### Initiative Templates

| Name | One-Time Cost | Monthly Recurring |
|------|--------------|-------------------|
| Server Replacement | $7,500.00 | $150.00/mo |
| Cloud Migration | $5,000.00 | $800.00/mo |
| Network Refresh | $4,000.00 | $600.00/mo |
| Email Security Upgrade | $1,500.00 | $120.00/mo |
| Backup & DR Modernization | $3,000.00 | $900.00/mo |

### Meeting Templates

| Name | Title Created |
|------|--------------|
| Quarterly Business Review | Q1 2026 Business Review & Strategic Planning |
| Network Assessment | IT Infrastructure & Network Assessment |
| Security & Compliance | Security Posture & Compliance Review |
| Technology Roadmap | 3-Year Technology Roadmap Planning |
| Budget & ROI Analysis | IT Budget Planning & ROI Analysis |

## Project Structure

```
.
├── ScalePad-Sandbox.ps1   # The recipe script
├── samples.json           # Initiative + meeting templates (edit to customize)
└── README.md
```

## Acknowledgments

This recipe was inspired by and built on initial work from **Tulsie Narine**, Senior Solutions Engineer at ScalePad.

## License

MIT
