from __future__ import annotations

import re
from io import StringIO

import pandas as pd

from .client import FetchResult, SportsReferenceClient


class BasketballReferenceNba:
    base_url = "https://www.basketball-reference.com"

    def __init__(self, client: SportsReferenceClient) -> None:
        self.client = client

    def fetch_dataset(
        self,
        dataset: str,
        season_end_year: int,
        *,
        force: bool = False,
    ) -> tuple[pd.DataFrame, FetchResult, str]:
        if season_end_year < 1947 or season_end_year > 2100:
            raise ValueError("season_end_year is outside the supported NBA range")
        mapping = {
            "player_per_game": (
                f"/leagues/NBA_{season_end_year}_per_game.html",
                ("per_game_stats", "per_game"),
            ),
            "player_totals": (
                f"/leagues/NBA_{season_end_year}_totals.html",
                ("totals_stats", "totals"),
            ),
            "player_advanced": (
                f"/leagues/NBA_{season_end_year}_advanced.html",
                ("advanced", "advanced_stats"),
            ),
            "playoff_player_per_game": (
                f"/playoffs/NBA_{season_end_year}_per_game.html",
                ("per_game_stats", "per_game"),
            ),
            "playoff_player_totals": (
                f"/playoffs/NBA_{season_end_year}_totals.html",
                ("totals_stats", "totals"),
            ),
            "playoff_player_advanced": (
                f"/playoffs/NBA_{season_end_year}_advanced.html",
                ("advanced", "advanced_stats"),
            ),
            "team_per_game": (
                f"/leagues/NBA_{season_end_year}.html",
                ("per_game-team", "team-stats-per_game", "team_per_game"),
            ),
            "team_opponent_per_game": (
                f"/leagues/NBA_{season_end_year}.html",
                ("per_game-opponent", "opponent-stats-per_game", "opponent_per_game"),
            ),
            "team_advanced": (
                f"/leagues/NBA_{season_end_year}.html",
                ("advanced-team", "team-stats-advanced", "team_advanced"),
            ),
            "schedule": (
                f"/leagues/NBA_{season_end_year}_games.html",
                ("schedule",),
            ),
        }
        if dataset == "standings":
            return self._standings(season_end_year, force=force)
        if dataset not in mapping:
            raise ValueError(f"Unsupported dataset: {dataset}")
        path, table_ids = mapping[dataset]
        return self._single_table(path, table_ids, force=force)

    def list_table_ids(
        self,
        season_end_year: int,
        *,
        page: str = "league",
        force: bool = False,
    ) -> tuple[list[str], FetchResult]:
        paths = {
            "league": f"/leagues/NBA_{season_end_year}.html",
            "per_game": f"/leagues/NBA_{season_end_year}_per_game.html",
            "totals": f"/leagues/NBA_{season_end_year}_totals.html",
            "advanced": f"/leagues/NBA_{season_end_year}_advanced.html",
            "schedule": f"/leagues/NBA_{season_end_year}_games.html",
            "playoff_per_game": f"/playoffs/NBA_{season_end_year}_per_game.html",
            "playoff_totals": f"/playoffs/NBA_{season_end_year}_totals.html",
            "playoff_advanced": f"/playoffs/NBA_{season_end_year}_advanced.html",
        }
        if page not in paths:
            raise ValueError(f"Unsupported page type: {page}")
        result = self.client.fetch(f"{self.base_url}{paths[page]}", force=force)
        return self.client.list_table_ids(result.html), result

    def _single_table(
        self,
        path: str,
        table_ids: tuple[str, ...],
        *,
        force: bool,
    ) -> tuple[pd.DataFrame, FetchResult, str]:
        result = self.client.fetch(f"{self.base_url}{path}", force=force)
        table, table_id = self.client.find_table(result.html, table_ids)
        frame = pd.read_html(StringIO(str(table)))[0]
        return self._clean(frame), result, table_id

    def _standings(
        self,
        season_end_year: int,
        *,
        force: bool,
    ) -> tuple[pd.DataFrame, FetchResult, str]:
        result = self.client.fetch(
            f"{self.base_url}/leagues/NBA_{season_end_year}.html",
            force=force,
        )
        frames = []
        used_ids = []
        soup = self.client.expanded_soup(result.html)
        for table_id in (
            "confs_standings_E",
            "confs_standings_W",
            "divs_standings_E",
            "divs_standings_W",
        ):
            table = soup.find("table", id=table_id)
            if table is None:
                continue
            frame = pd.read_html(StringIO(str(table)))[0]
            frame["standings_table"] = table_id
            frames.append(frame)
            used_ids.append(table_id)
        if not frames:
            raise LookupError(
                "No standings table was found. Run the table-list command to inspect the page."
            )
        combined = pd.concat(frames, ignore_index=True)
        return self._clean(combined), result, ",".join(used_ids)

    def _clean(self, frame: pd.DataFrame) -> pd.DataFrame:
        frame = frame.copy()
        if isinstance(frame.columns, pd.MultiIndex):
            frame.columns = [
                "_".join(str(part) for part in column if str(part) != "nan")
                for column in frame.columns
            ]
        frame.columns = [self._snake_case(str(column)) for column in frame.columns]
        for rank_column in ("rk", "rank"):
            if rank_column in frame.columns:
                frame = frame[
                    frame[rank_column].astype(str).str.lower() != rank_column
                ]
        frame = frame.dropna(how="all").reset_index(drop=True)
        for column in frame.columns:
            if frame[column].dtype == object:
                frame[column] = frame[column].map(
                    lambda value: value.strip() if isinstance(value, str) else value
                )
        return frame

    def _snake_case(self, value: str) -> str:
        value = value.replace("%", "_pct").replace("+/-", "plus_minus")
        value = re.sub(r"[^a-zA-Z0-9]+", "_", value).strip("_")
        return value.lower()
