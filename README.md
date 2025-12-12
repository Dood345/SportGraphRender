# **SportGraph**

A high-performance football analytics platform built using **FastAPI**, **Neo4j**, and **Python**, with full graph-based teammate analysis, club history modeling, shortest-path queries, and automated FBref data scraping.

SportGraph models football as a **player-teammate graph**, enabling deep reasoning about how players connect across clubs, seasons, and leagues.

---

## **📌 Key Features**

### **Graph Analytics API**

-   Player search with normalized fuzzy matching
-   Player club history per season
-   Club roster aggregation with filters:

    -   min/max appearances
    -   season range
    -   sort order

-   N-step teammate chain MCQ generator

    -   hides internal nodes
    -   produces distractors using XOR teammate logic

-   Shortest teammate path (name or ID)

### **Scraper (FBref Big-5 Leagues)**

-   Automated multi-season scraper for:

    -   Premier League
    -   La Liga
    -   Serie A
    -   Bundesliga
    -   Ligue 1

-   Normalizes player profile links
-   Extracts season-by-season club statistics
-   Generates CSV output
-   Writes per-player progress to avoid duplicate scraping

### **Production Deployment**

-   Systemd service (`sportgraph.service`)
-   Auto-update Bash script (`deploy.sh`)
-   Async Neo4j driver with connection pooling

### **Developer Experience**

-   Full Makefile workflow:

    -   Virtual env management
    -   Install dependencies
    -   Run API locally
    -   Run tests
    -   Coverage reports

-   Works on **Windows**, **macOS**, and **Linux** (OS-aware)

---

# **📁 Project Structure**

```
SportGraph/
│
├── api/
│   ├── src/
│   │   ├── database/
│   │   │   └── neo4j_connection_manager.py
│   │   ├── repository/
│   │   │   └── neo4j_graph_repository.py
│   │   ├── service/
│   │   │   └── soccer_service.py
│   │   └── router/
│   │       └── soccer_router.py
│   └── main.py
│
├── script/
│   └── scrape_fbref_player.py
│
├── deploy.sh
├── Makefile
├── requirements.txt
├── .env
└── README.md
```

---

# **⚙️ Setup Instructions**

## **1. Create a `.env` File**

Your Makefile requires `.env` before running any commands.

Example:

```
VENV_DIR=venv
REQ_FILE=requirements.txt
API_HOST=127.0.0.1
PORT=8000
API_RELOAD_DIR=api/src

NEO4J_URI=bolt://localhost:7687
NEO4J_USER=neo4j
NEO4J_PASSWORD=yourpassword
```

---

# **📦 Virtual Environment Commands (Makefile)**

### **Create venv**

```
make venv-create
```

### **Install dependencies**

```
make venv-install
```

### **Ensure venv exists**

```
make venv-ensure
```

### **Open virtual environment shell**

```
make venv-shell
```

---

# **🚀 Running the API**

Start the FastAPI backend (auto-reload enabled):

```
make api-run
```

Runs:

```
http://localhost:8000
```

Open docs:

```
http://localhost:8000/docs
```

---

# **🧪 Run Tests**

### **Run API test suite**

```
make api-test
```

### **Run with coverage**

```
make api-coverage
```

Outputs:

-   Terminal report
-   HTML report → `htmlcov/`
-   XML report → `coverage.xml`

---

# **🧠 API Overview**

## **Player Endpoints**

| Method | Endpoint                      | Description          |
| ------ | ----------------------------- | -------------------- |
| GET    | `/soccer/player/id`           | Get player by ID     |
| GET    | `/soccer/player/name`         | Search players       |
| GET    | `/soccer/player/history/id`   | Club history by ID   |
| GET    | `/soccer/player/history/name` | Club history by name |

---

## **Club Player Analytics**

```
GET /soccer/club/players
```

Filters:

-   `min_apps`, `max_apps`
-   `season_from`, `season_to`
-   Sorting: `appearances`, `first_season`, `last_season`, `name`

---

## **Teammate MCQ Questions**

```
GET /soccer/teammates/question
```

Produces questions like:

"Given Player A and Player C, who was the missing teammate between them?"

### Logic used:

-   N-step PLAYED_WITH path
-   Hide internal players
-   Each hidden node gets multiple-choice distractors
-   Distractors selected using XOR teammate rule

---

## **Shortest Teammate Path**

| Endpoint                          | Description                     |
| --------------------------------- | ------------------------------- |
| `/soccer/teammates/shortest/id`   | Shortest chain using player IDs |
| `/soccer/teammates/shortest/name` | Shortest chain using names      |

Returns:

-   ordered list of players
-   clubs on each hop
-   total path length

---

# **📊 Scraper**

### Run the FBref scraper:

```
python script/scrape_fbref_player.py
```

Outputs:

-   `data/player_club_history.csv`
-   `data/completed_players.txt`

Automatically:

-   handles retries
-   restarts Selenium on failure
-   flushes data every write
-   normalizes URLs
-   merges consecutive seasons for same club

---

# **🚀 Deployment (Linux Server)**

### Deploy latest version:

```
./deploy.sh
```

Does:

1. `git pull`
2. `pip install -r requirements.txt`
3. `systemctl restart sportgraph`
4. Shows service status

---

### **🧱 Systemd Example**

```
[Unit]
Description=SportGraph API
After=network.target

[Service]
User=ubuntu
WorkingDirectory=/opt/SportGraph/api
ExecStart=/opt/SportGraph/venv/bin/python -m api.src.main
Restart=always

[Install]
WantedBy=multi-user.target
```

---

# **📘 Architecture Overview**

### **1. API Layer (FastAPI)**

Handles routing, validation, CORS, and returning structured responses.

### **2. Service Layer**

Implements:

-   teammate chain inference
-   MCQ generator
-   sorting/filter logic
-   input validation

### **3. Repository Layer**

Handles all Neo4j queries:

-   shortest paths
-   path expansion with APOC
-   club histories
-   distractor generation

### **4. Data Layer**

Asynchronous Neo4j driver with:

-   connection pooling
-   error logging
-   safe session handling

### **5. Scraper Layer**

Collects raw data → CSV → loaded into Neo4j.

---
