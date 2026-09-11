from __future__ import annotations

import json
import re
import unicodedata
from pathlib import Path
from typing import Any, Iterable

from tools.build_static_nba_website_data import write_json
from tools.nba_awards_user_supplement_full import rows as full_user_award_rows

SOURCE_KEY = "user_supplied_awards_2026_09_10"


def _season(start_year: int) -> str:
    return f"{start_year:04d}-{(start_year + 1) % 100:02d}"


def _season_for_award_year(year: int) -> str:
    return _season(year - 1)


def _name_token(value: Any) -> str:
    text = unicodedata.normalize("NFKD", str(value or ""))
    text = "".join(ch for ch in text if not unicodedata.combining(ch))
    text = re.sub(r"\([^)]*\)", " ", text)
    text = text.replace("†", " ").replace("^", " ").replace("*", " ").replace("§", " ")
    text = text.replace("’", "'")
    return re.sub(r"[^a-z0-9]+", "", text.lower())


def _row(
    season_id: str,
    award_key: str,
    award: str,
    player_name: str,
    *,
    team: str = "",
    selection_team: str = "",
    player_honor: bool = True,
) -> dict[str, Any]:
    result: dict[str, Any] = {
        "league_id": "NBA",
        "season_id": season_id,
        "award_key": award_key,
        "award": award,
        "award_name": award,
        "player_name": player_name,
        "winner": True,
        "selected": bool(selection_team),
        "source_key": SOURCE_KEY,
        "manual_static_supplement": True,
        "player_honor": player_honor,
    }
    if team:
        result["team_text"] = team
    if selection_team:
        result["selection_team"] = selection_team
        result["rank_text"] = selection_team
    return result


def _asg_mvp_rows() -> list[dict[str, Any]]:
    winners: dict[int, list[str]] = {
        1951:["Ed Macauley"],1952:["Paul Arizin"],1953:["George Mikan"],1954:["Bob Cousy"],1955:["Bill Sharman"],1956:["Bob Pettit"],1957:["Bob Cousy"],1958:["Bob Pettit"],1959:["Elgin Baylor","Bob Pettit"],1960:["Wilt Chamberlain"],1961:["Oscar Robertson"],1962:["Bob Pettit"],1963:["Bill Russell"],1964:["Oscar Robertson"],1965:["Jerry Lucas"],1966:["Adrian Smith"],1967:["Rick Barry"],1968:["Hal Greer"],1969:["Oscar Robertson"],1970:["Willis Reed"],1971:["Lenny Wilkens"],1972:["Jerry West"],1973:["Dave Cowens"],1974:["Bob Lanier"],1975:["Walt Frazier"],1976:["Dave Bing"],1977:["Julius Erving"],1978:["Randy Smith"],1979:["David Thompson"],1980:["George Gervin"],1981:["Nate Archibald"],1982:["Larry Bird"],1983:["Julius Erving"],1984:["Isiah Thomas"],1985:["Ralph Sampson"],1986:["Isiah Thomas"],1987:["Tom Chambers"],1988:["Michael Jordan"],1989:["Karl Malone"],1990:["Magic Johnson"],1991:["Charles Barkley"],1992:["Magic Johnson"],1993:["John Stockton","Karl Malone"],1994:["Scottie Pippen"],1995:["Mitch Richmond"],1996:["Michael Jordan"],1997:["Glen Rice"],1998:["Michael Jordan"],2000:["Shaquille O'Neal","Tim Duncan"],2001:["Allen Iverson"],2002:["Kobe Bryant"],2003:["Kevin Garnett"],2004:["Shaquille O'Neal"],2005:["Allen Iverson"],2006:["LeBron James"],2007:["Kobe Bryant"],2008:["LeBron James"],2009:["Kobe Bryant","Shaquille O'Neal"],2010:["Dwyane Wade"],2011:["Kobe Bryant"],2012:["Kevin Durant"],2013:["Chris Paul"],2014:["Kyrie Irving"],2015:["Russell Westbrook"],2016:["Russell Westbrook"],2017:["Anthony Davis"],2018:["LeBron James"],2019:["Kevin Durant"],2020:["Kawhi Leonard"],2021:["Giannis Antetokounmpo"],2022:["Stephen Curry"],2023:["Jayson Tatum"],2024:["Damian Lillard"],2025:["Stephen Curry"],2026:["Anthony Edwards"],
    }
    return [_row(_season_for_award_year(year),"all_star_game_mvp","All-Star Game MVP",player,player_honor=False) for year,players in winners.items() for player in players]


def _recent_award_rows() -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    annual = [
        ("2023-24","mvp","Most Valuable Player","Nikola Jokić","Denver Nuggets",True),("2024-25","mvp","Most Valuable Player","Shai Gilgeous-Alexander","Oklahoma City Thunder",True),("2025-26","mvp","Most Valuable Player","Shai Gilgeous-Alexander","Oklahoma City Thunder",True),
        ("2023-24","rookie_of_year","Rookie of the Year","Victor Wembanyama","San Antonio Spurs",True),("2024-25","rookie_of_year","Rookie of the Year","Stephon Castle","San Antonio Spurs",True),("2025-26","rookie_of_year","Rookie of the Year","Cooper Flagg","Dallas Mavericks",True),
        ("2023-24","dpoy","Defensive Player of the Year","Rudy Gobert","Minnesota Timberwolves",True),("2024-25","dpoy","Defensive Player of the Year","Evan Mobley","Cleveland Cavaliers",True),("2025-26","dpoy","Defensive Player of the Year","Victor Wembanyama","San Antonio Spurs",True),
        ("2023-24","sixth_man","Sixth Man of the Year","Naz Reid","Minnesota Timberwolves",True),("2024-25","sixth_man","Sixth Man of the Year","Payton Pritchard","Boston Celtics",True),("2025-26","sixth_man","Sixth Man of the Year","Keldon Johnson","San Antonio Spurs",True),
        ("2023-24","most_improved","Most Improved Player","Tyrese Maxey","Philadelphia 76ers",True),("2024-25","most_improved","Most Improved Player","Dyson Daniels","Atlanta Hawks",True),("2025-26","most_improved","Most Improved Player","Nickeil Alexander-Walker","Atlanta Hawks",True),
        ("2022-23","clutch_player","Clutch Player of the Year","De'Aaron Fox","Sacramento Kings",True),("2023-24","clutch_player","Clutch Player of the Year","Stephen Curry","Golden State Warriors",True),("2024-25","clutch_player","Clutch Player of the Year","Jalen Brunson","New York Knicks",True),("2025-26","clutch_player","Clutch Player of the Year","Shai Gilgeous-Alexander","Oklahoma City Thunder",True),
        ("2023-24","sportsmanship","Sportsmanship Award","Tyrese Maxey","Philadelphia 76ers",False),("2024-25","sportsmanship","Sportsmanship Award","Jrue Holiday","Boston Celtics",False),("2025-26","sportsmanship","Sportsmanship Award","Derrick White","Boston Celtics",False),
        ("2023-24","teammate_of_year","Teammate of the Year","Mike Conley","Minnesota Timberwolves",False),("2024-25","teammate_of_year","Teammate of the Year","Stephen Curry","Golden State Warriors",False),("2025-26","teammate_of_year","Teammate of the Year","DeAndre Jordan","New Orleans Pelicans",False),
        ("2023-24","social_justice","Social Justice Champion","Karl-Anthony Towns","Minnesota Timberwolves",False),("2024-25","social_justice","Social Justice Champion","Jrue Holiday","Boston Celtics",False),("2025-26","social_justice","Social Justice Champion","Bam Adebayo","Miami Heat",False),
        ("2023-24","hustle_award","Hustle Award","Alex Caruso","Chicago Bulls",False),("2024-25","hustle_award","Hustle Award","Draymond Green","Golden State Warriors",False),("2025-26","hustle_award","Hustle Award","Moussa Diabaté","Charlotte Hornets",False),
    ]
    rows.extend(_row(season_id,key,label,player,team=team,player_honor=player_honor) for season_id,key,label,player,team,player_honor in annual)
    return rows


def supplemental_awards() -> list[dict[str, Any]]:
    return [*_asg_mvp_rows(), *_recent_award_rows(), *full_user_award_rows()]


def _existing_key(row: dict[str, Any]) -> tuple[str, str, str, str]:
    award_key = str(row.get("award_key") or "").strip().lower()
    if not award_key:
        raw = str(row.get("award") or row.get("award_name") or "").lower().replace("_", " ").replace("-", " ")
        selection = str(row.get("selection_team") or row.get("rank_text") or "").lower()
        if "all nba" in raw:
            award_key = "all_nba_" + ("first" if "first" in selection or "1st" in selection else "second" if "second" in selection or "2nd" in selection else "third" if "third" in selection or "3rd" in selection else "")
        elif "all defense" in raw:
            award_key = "all_defense_" + ("first" if "first" in selection or "1st" in selection else "second" if "second" in selection or "2nd" in selection else "")
        elif "all rookie" in raw:
            award_key = "all_rookie_" + ("first" if "first" in selection or "1st" in selection else "second" if "second" in selection or "2nd" in selection else "")
        else:
            award_key = re.sub(r"[^a-z0-9]+", "_", raw).strip("_")
    return (str(row.get("season_id") or ""), award_key, str(row.get("player_key") or _name_token(row.get("player_name"))), str(row.get("selection_team") or "").lower())


def _load_json(path: Path, fallback: Any) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return fallback


def apply_award_supplement(output: Path) -> dict[str, int]:
    history_path = output / "history" / "awards.json"
    player_index_path = output / "players" / "index.json"
    if not history_path.is_file() or not player_index_path.is_file():
        return {"added_history": 0, "added_player": 0, "unmatched_players": 0}
    history = _load_json(history_path, [])
    if not isinstance(history, list): history=[]
    players = _load_json(player_index_path, [])
    if not isinstance(players, list): players=[]
    player_by_name: dict[str, dict[str, Any]] = {}
    for item in players:
        if isinstance(item, dict):
            token=_name_token(item.get("canonical_name"))
            if token: player_by_name[token]=item
    additions=supplemental_awards()
    unmatched:set[str]=set()
    for row in additions:
        match=player_by_name.get(_name_token(row.get("player_name")))
        if match:
            row["player_key"]=match.get("player_key")
            row["player_name"]=match.get("canonical_name") or row.get("player_name")
        else:
            unmatched.add(str(row.get("player_name") or ""))
    seen={_existing_key(row) for row in history if isinstance(row,dict)}
    added_history=0
    for row in additions:
        key=_existing_key(row)
        if key in seen: continue
        history.append(row); seen.add(key); added_history+=1
    history.sort(key=lambda row:(str(row.get("season_id") or ""),str(row.get("award_key") or row.get("award") or ""),str(row.get("player_name") or "")))
    write_json(history_path,history)
    additions_by_player:dict[str,list[dict[str,Any]]]={}
    for row in additions:
        player_key=str(row.get("player_key") or "")
        if player_key and row.get("player_honor") is True:
            additions_by_player.setdefault(player_key,[]).append(row)
    added_player=0
    for player in players:
        if not isinstance(player,dict): continue
        player_key=str(player.get("player_key") or "")
        if player_key not in additions_by_player: continue
        file_name=str(player.get("file") or "")
        if not file_name: continue
        dossier_path=output/file_name
        dossier=_load_json(dossier_path,{})
        if not isinstance(dossier,dict): continue
        dossier_awards=dossier.get("awards")
        if not isinstance(dossier_awards,list): dossier_awards=[]
        dossier_seen={_existing_key(row) for row in dossier_awards if isinstance(row,dict)}
        for row in additions_by_player[player_key]:
            key=_existing_key(row)
            if key in dossier_seen: continue
            dossier_awards.append(dict(row)); dossier_seen.add(key); added_player+=1
        dossier_awards.sort(key=lambda row:(str(row.get("season_id") or ""),str(row.get("award_key") or row.get("award") or "")))
        dossier["awards"]=dossier_awards
        summary=dossier.get("summary")
        if isinstance(summary,dict): summary["awards"]=len(dossier_awards)
        write_json(dossier_path,dossier)
    manifest_path=output/"manifest.json"
    manifest=_load_json(manifest_path,{})
    if isinstance(manifest,dict):
        manifest["award_count"]=len(history)
        manifest["manual_awards_supplement"]={"source_key":SOURCE_KEY,"rows":len(additions),"added_history_rows":added_history,"added_player_honors":added_player,"unmatched_player_names":sorted(name for name in unmatched if name)}
        write_json(manifest_path,manifest)
    return {"added_history":added_history,"added_player":added_player,"unmatched_players":len([name for name in unmatched if name])}


if __name__ == "__main__":
    import argparse
    parser=argparse.ArgumentParser(description="Merge the user-supplied static NBA awards supplement into a compiled corpus.")
    parser.add_argument("--output",default=str(Path(__file__).resolve().parents[1]/"web/data/nba_static"))
    args=parser.parse_args()
    result=apply_award_supplement(Path(args.output).expanduser().resolve())
    print(f"Static NBA awards supplement: {result['added_history']} history rows; {result['added_player']} player-honor rows; {result['unmatched_players']} unmatched player names")
