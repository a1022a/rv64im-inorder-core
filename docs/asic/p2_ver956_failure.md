# P2 VER-956 failure

P2 commit `c6d08ff57f0e8cdaf734aa8b8d63a6b569850af2` passed functional qualification and exact-source validation. Authorized DC checkout passed, but fresh analyze failed with VER-956 because `div_ready` was referenced before its declaration. No synthesis, PT setup, or PT hold was performed, so timing effectiveness was NOT_EVALUATED. P2R1 resolved the compatibility issue by moving only the existing declaration before first use; Boolean logic and cycle behavior were unchanged.
