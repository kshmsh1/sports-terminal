from __future__ import annotations

from pathlib import Path


def main() -> None:
    auth = Path('backend/app/auth_api.py').read_text(encoding='utf-8')
    launch = Path('backend/app/main_launch.py').read_text(encoding='utf-8')
    awards = Path('backend/app/historical_nba_awards_api.py').read_text(encoding='utf-8')

    assert 'CREATE TABLE IF NOT EXISTS legal_acceptances' in auth
    assert 'accepted_terms: bool = False' in auth
    assert 'accepted_privacy: bool = False' in auth
    assert 'TERMS_VERSION = "2026-08-08-v1"' in auth
    assert 'PRIVACY_VERSION = "2026-08-08-v1"' in auth
    assert 'historical_nba_awards_router' in launch
    assert '_attach_router_routes(historical_nba_awards_router)' in launch

    for award_id in [
        'mvp', 'rookie_of_the_year', 'defensive_player_of_the_year',
        'sixth_man', 'most_improved', 'clutch_player', 'finals_mvp',
        'eastern_conference_finals_mvp', 'western_conference_finals_mvp',
        'all_star', 'all_star_mvp', 'all_nba_first', 'all_nba_second',
        'all_nba_third', 'all_defense_first', 'all_defense_second',
        'all_rookie_first', 'all_rookie_second', 'sportsmanship',
        'social_justice_champion', 'citizenship', 'teammate_of_the_year',
        'hustle_award', 'coach_of_the_year', 'executive_of_the_year',
    ]:
        assert f'"{award_id}"' in awards, award_id

    print('Sports Terminal platform expansion backend contract passed.')


if __name__ == '__main__':
    main()
