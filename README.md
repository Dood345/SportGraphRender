# **SportGraph**

A high-performance football analytics platform built using **FastAPI** and **Python**, with full graph-based teammate analysis, club history modeling, shortest-path queries, and automated FBref data scraping.

SportGraph models football as a **player-teammate graph**, enabling deep reasoning about how players connect across clubs, seasons, and leagues.

---

## **📌 Key Features**

### **Graph Analytics API (In-Memory)**
Powered by `pandas` and `networkx`, running entirely in memory for high performance and zero-dependency deployment.

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
    -   Premier League, La Liga, Serie A, Bundesliga, Ligue 1
-   Normalizes player profile links
-   Extracts season-by-season club statistics
-   Generates CSV output (`data/save.csv`) which powers the graph.

### **Simple Deployment**
-   Runs as a standard Python application.
-   No external database required (Neo4j removed).
-   Ready for Render, Railway, or any Python hosting.

---

# **📁 Project Structure**

```
SportGraph/
│
├── api/
│   ├── src/
│   │   ├── repository/
│   │   │   └── memory_graph_repository.py  # Core graph logic (NetworkX)
│   │   ├── service/
│   │   │   └── soccer_service.py           # Business logic
│   │   └── router/
│   │       └── soccer_router.py            # API endpoints
│   └── main.py
│
├── data/
│   └── save.csv                            # Graph data source
│
├── script/
│   └── scrape_fbref_player.py              # Scraper script
│
├── requirements.txt
├── .env
├── Makefile
└── README.md
```

---

# **⚙️ Setup Instructions**

## **1. Create a `.env` File**
Optional, but recommended.

```
VENV_DIR=venv
REQ_FILE=requirements.txt
API_HOST=127.0.0.1
PORT=8000
API_RELOAD_DIR=api/src
FRONTEND_URL=http://localhost:5173
```

---

# **📦 Virtual Environment Commands (Makefile)**

### **Create & Install**
```
make venv-install
```

### **Open Shell**
```
make venv-shell
```

---

# **🚀 Running the API**

Start the FastAPI backend:

```
make api-run
```

Or manually:
```
uvicorn api.src.main:app --host 0.0.0.0 --port 8000 --reload
```

Runs:
```
http://localhost:8000
```

Docs:
```
http://localhost:8000/docs
```

---

# **🧪 Run Tests**

```
make api-test
```

With coverage:
```
make api-coverage
```

---

# **🚀 Deployment**

### **Build**
```
pip install -r requirements.txt
```

### **Run**
```
uvicorn api.src.main:app --host 0.0.0.0 --port $PORT
```

---
