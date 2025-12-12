import pandas as pd
import networkx as nx
import logging
import os
import random
from typing import List, Dict, Any, Optional, Tuple, Set

logger = logging.getLogger(__name__)

class MemoryGraphRepository:
    def __init__(self, csv_path: str = "data/save.csv"):
        self.csv_path = csv_path
        self.df = pd.DataFrame()
        self.G = nx.Graph()
        self._load_data()
        self._build_graph()

    def _load_data(self):
        """Load CSV data into Pandas DataFrame."""
        if not os.path.exists(self.csv_path):
            # Fallback for different CWD
            if os.path.exists(f"../{self.csv_path}"):
                self.csv_path = f"../{self.csv_path}"
            elif os.path.exists(os.path.join(os.getcwd(), "data", "save.csv")):
                 self.csv_path = os.path.join(os.getcwd(), "data", "save.csv")
            else:
                logger.error(f"Data file not found at {self.csv_path}")
                return

        logger.info(f"Loading data from {self.csv_path}")
        self.df = pd.read_csv(self.csv_path)
        
        # Clean / Normalize data
        # Ensure strings
        self.df['player_id'] = self.df['player_id'].astype(str)
        self.df['player_name'] = self.df['player_name'].astype(str)
        self.df['club'] = self.df['club'].astype(str)
        self.df['start'] = self.df['start'].astype(str)
        self.df['end'] = self.df['end'].astype(str)
        self.df['appearances'] = pd.to_numeric(self.df['appearances'], errors='coerce').fillna(0).astype(int)

        # Parse years roughly
        def parse_year(val):
            if "-" in val:
                return int(val.split("-")[0])
            try:
                return int(val)
            except:
                return 0
        
        def parse_end_year(val):
            if "-" in val:
                return int(val.split("-")[1])
            try:
                return int(val)
            except:
                return 0

        self.df['start_year'] = self.df['start'].apply(parse_year)
        self.df['end_year'] = self.df['end'].apply(parse_end_year)

    def _build_graph(self):
        """Build NetworkX graph from DataFrame."""
        logger.info("Building Teammate Graph...")
        self.G.clear()

        # Add nodes
        # Group by player_id to get unique players
        players = self.df.groupby('player_id')['player_name'].first()
        for pid, name in players.items():
            self.G.add_node(pid, name=name)

        # Build edges (Teammates)
        # Strategy: Expand player-club-ranges into player-club-year buckets
        # Two players in the same (club, year) bucket are teammates.
        
        # Create a list of (club, year, player_id)
        season_entries = []
        for _, row in self.df.iterrows():
            pid = row['player_id']
            club = row['club']
            s = row['start_year']
            e = row['end_year']
            
            # Sanity check years
            if s > 0 and e >= s:
                for y in range(s, e + 1):
                    season_entries.append((club, y, pid))
        
        season_df = pd.DataFrame(season_entries, columns=['club', 'year', 'player_id'])
        
        # Group by (club, year)
        grouped = season_df.groupby(['club', 'year'])['player_id'].apply(list)
        
        edge_weights: Dict[Tuple[str, str], Dict[str, Any]] = {}

        # Iterate groups and form cliques
        for (club, year), pids in grouped.items():
            pids = list(set(pids)) # Unique players in that squad
            if len(pids) < 2:
                continue
            
            # Sort to ensure consistent edge keys
            pids.sort()
            
            for i in range(len(pids)):
                for j in range(i + 1, len(pids)):
                    p1, p2 = pids[i], pids[j]
                    
                    if (p1, p2) not in edge_weights:
                        edge_weights[(p1, p2)] = {'weight': 0, 'clubs': set(), 'seasons': 0}
                    
                    edge_weights[(p1, p2)]['weight'] += 1 # Rough weight
                    edge_weights[(p1, p2)]['seasons'] += 1
                    edge_weights[(p1, p2)]['clubs'].add(club)

        # Add edges to graph
        for (p1, p2), data in edge_weights.items():
            # Calculate final attributes
            # club string (comma joined if multiple, though rarely happens seamlessly like that in model)
            # In neo4j logic: "c.name" was used. If multiple clubs, we might pick one or join them.
            # For simplicity, join them.
            club_str = ", ".join(sorted(list(data['clubs'])))
            
            self.G.add_edge(p1, p2, weight=data['weight'], club=club_str)

        logger.info(f"Graph built: {self.G.number_of_nodes()} nodes, {self.G.number_of_edges()} edges")

    # ==========================
    # Repository Methods
    # ==========================

    async def get_player_by_id(self, player_id: str) -> Optional[Dict[str, Any]]:
        if self.G.has_node(player_id):
            return {"id": player_id, "name": self.G.nodes[player_id].get("name")}
        return None

    async def search_players(self, name: str) -> List[Dict[str, Any]]:
        name_lower = name.lower()
        normalized = name.lower().replace(' ', '-')
        
        results = []
        
        # Pre-aggregate appearances for ranking
        # Apps per player
        apps_map = self.df.groupby('player_id')['appearances'].sum().to_dict()

        for pid, data in self.G.nodes(data=True):
            pname = data.get('name', '')
            pname_lower = pname.lower()
            
            if normalized in pname_lower or name_lower in pname_lower:
                 results.append({
                     "id": pid,
                     "name": pname,
                     "appearances": apps_map.get(pid, 0)
                 })
        
        # Sort by appearances desc
        results.sort(key=lambda x: x['appearances'], reverse=True)
        return results[:25]

    async def get_player_club_history(self, player_id: str) -> List[Dict[str, Any]]:
        rows = self.df[self.df['player_id'] == player_id].copy()
        if rows.empty:
            return []
        
        # Sort by start year
        rows.sort_values(by='start_year', inplace=True)
        
        history = []
        for _, row in rows.iterrows():
            history.append({
                "club": row['club'],
                "start": row['start_year'], # Using parsed int years for consistency
                "end": row['end_year'],
                "apps": row['appearances']
            })
        return history

    async def get_club_players(
        self,
        club_name: str,
        min_apps: Optional[int] = None,
        max_apps: Optional[int] = None,
        season_from: Optional[int] = None,
        season_to: Optional[int] = None,
        order_by: str = "appearances",
        order_dir: str = "desc",
    ) -> List[Dict[str, Any]]:
        
        # Filter
        mask = self.df['club'] == club_name
        if min_apps is not None:
            mask &= (self.df['appearances'] >= min_apps)
        if max_apps is not None:
            mask &= (self.df['appearances'] <= max_apps)
        if season_from is not None:
            mask &= (self.df['start_year'] >= season_from)
        if season_to is not None:
            mask &= (self.df['end_year'] <= season_to)
            
        filtered = self.df[mask]
        
        # Group by player to aggregate (if a player played multiple spells at one club)
        # Though the API spec implies returning individual rows or aggregated? 
        # Neo4j query did: sum(r.appearances), min(start), max(end)
        
        grouped = filtered.groupby(['player_id', 'player_name']).agg({
            'appearances': 'sum',
            'start_year': 'min',
            'end_year': 'max'
        }).reset_index()
        
        grouped.rename(columns={'start_year': 'first_season', 'end_year': 'last_season', 'player_name': 'name', 'player_id': 'id'}, inplace=True)
        
        # Sort
        ascending = (order_dir == "asc")
        if order_by not in grouped.columns:
            order_by = 'appearances'
            
        grouped.sort_values(by=order_by, ascending=ascending, inplace=True)
        
        return grouped.to_dict('records')

    async def get_n_step_teammate_paths(self, steps: int = 2, limit: int = 10) -> List[Dict[str, Any]]:
        # This is the simplified N-step logic.
        # Steps = 2 means Player A -> B -> C (2 edges).
        # Finding *random* paths of length N is hard to do efficiently in NX without simple random walk.
        
        paths_found = []
        nodes = list(self.G.nodes())
        
        # Try random walks
        attempts = 0
        max_attempts = limit * 20 
        
        while len(paths_found) < limit and attempts < max_attempts:
            attempts += 1
            start_node = random.choice(nodes)
            
            # Perform BFS/DFS restricted to depth 'steps'??
            # Or just random walk
            path = [start_node]
            curr = start_node
            valid = True
            
            for _ in range(steps):
                neighbors = list(self.G.neighbors(curr))
                # Filter neighbors not already in path (simple loop avoidance)
                valid_neighbors = [n for n in neighbors if n not in path]
                
                if not valid_neighbors:
                    valid = False
                    break
                
                next_node = random.choice(valid_neighbors)
                path.append(next_node)
                curr = next_node
            
            if valid:
                # Calculate path details
                # Edges:
                edges_data = []
                total_weight = 0
                path_clubs = []
                
                # Check clause: consecutive clubs must differ
                # Check clause: no shortcuts (A and C shouldn't be connected if A-B-C)
                
                path_valid_logic = True
                
                # Verify edges and clubs
                for i in range(len(path) - 1):
                    u, v = path[i], path[i+1]
                    edata = self.G.get_edge_data(u, v)
                    club_name = edata['club'].split(", ")[0] # Pick first club if multiple
                    weight = edata['weight']
                    
                    path_clubs.append(club_name)
                    total_weight += weight
                
                # 1) Consecutive clubs must differ
                for i in range(len(path_clubs) - 1):
                    if path_clubs[i] == path_clubs[i+1]:
                        path_valid_logic = False
                        break
                
                if not path_valid_logic:
                    continue

                # 2) No shortcuts (Between non-adjacent nodes)
                # For path A-B-C, check A-C edge existence
                for i in range(len(path) - 2):
                    for j in range(i + 2, len(path)):
                        if self.G.has_edge(path[i], path[j]):
                            path_valid_logic = False
                            break
                            
                if not path_valid_logic:
                    continue
                
                # Construct result
                players_res = [{"id": pid, "name": self.G.nodes[pid]['name']} for pid in path]
                
                # Avoid duplicates in result set?
                paths_found.append({
                    "players": players_res,
                    "clubs": path_clubs,
                    "totalWeight": total_weight
                })

        # Sort by weight? Random shuffle?
        random.shuffle(paths_found)
        return paths_found

    async def get_options(self, a: str, b: str, c: str, limit: int) -> Optional[List[Dict[str, Any]]]:
        # XOR logic: find x such that x connected to A XOR x connected to C
        # And x is not A, B, C
        
        all_nodes = set(self.G.nodes())
        candidates = []
        
        # Optimization: Candidate pool is Neighbors(A) Union Neighbors(C)
        nA = set(self.G.neighbors(a)) if self.G.has_node(a) else set()
        nC = set(self.G.neighbors(c)) if self.G.has_node(c) else set()
        
        pool = nA.union(nC)
        
        for x in pool:
            if x in [a, b, c]:
                continue
            
            toA = x in nA
            toC = x in nC
            
            if toA != toC: # XOR
                candidates.append(x)
        
        # Shuffle candidates
        random.shuffle(candidates)
        candidates = candidates[:limit]
        
        # Format
        distractors = [{"id": x, "name": self.G.nodes[x]['name']} for x in candidates]
        
        # Add B (correct answer) ?? The interface expects B + distractors shuffled?
        # The Neo4j query returned [B] + distractors -> Shuffled.
        
        b_node = {"id": b, "name": self.G.nodes[b]['name']}
        options = [b_node] + distractors
        random.shuffle(options)
        
        return options

    async def get_shortest_teammate_path(self, player_a: str, player_b: str) -> Optional[Dict[str, Any]]:
        if not self.G.has_node(player_a) or not self.G.has_node(player_b):
            return None
            
        try:
            path = nx.shortest_path(self.G, source=player_a, target=player_b)
        except nx.NetworkXNoPath:
            return None
            
        # Reconstruct edges
        players = [{"id": pid, "name": self.G.nodes[pid]['name']} for pid in path]
        clubs = []
        
        for i in range(len(path) - 1):
             u, v = path[i], path[i+1]
             edata = self.G.get_edge_data(u, v)
             # Use the first club in the list (or string)
             clubs.append(edata['club'])
             
        return {
            "players": players,
            "clubs": clubs,
            "length": len(clubs)
        }
