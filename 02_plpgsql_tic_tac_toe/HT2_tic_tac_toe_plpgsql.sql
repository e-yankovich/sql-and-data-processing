create or replace function newgame() returns void as $$
begin
    -- Drop the game board if it already exists
    drop table if exists game_board;

    -- Create a new game board
    create table game_board (
        id char(2) primary key,
        y1 char(1) default null,
        y2 char(1) default null,
        y3 char(1) default null
    );

    -- Populate the game board with empty rows
    insert into game_board (id) values 
        ('x1'),
        ('x2'),
        ('x3');

    -- Drop the validation table if it already exists (to avoid carrying state between games)
    drop table if exists validation;

    -- Create a new validation table
    create table validation (
        id integer primary key default 1 check (id = 1),
        last_move char(1) default null,
        number_of_moves int default 0,
        status text default 'Game in progress' -- game status column
    );

    -- Insert initial values
    insert into validation default values;
end;
$$ language plpgsql;


create or replace function update_status(new_status text) 
returns void as $$  
begin
    -- Update the game status in the validation table
    update validation as v  
    set status = new_status
    where v.id = 1;
end;
$$ language plpgsql;


create or replace function nextmove(row_num int, col_num int, mark char(1)) 
returns table (row1 text, row2 text, row3 text, game_status text) as $$

declare
    last_move_data char(1);
    number_of_moves_data int;
    row_id char(2);
    winner char(1);
begin
    -- Fetch current state from validation
    select last_move, number_of_moves
    into last_move_data, number_of_moves_data
    from validation
    where validation.id = 1;

    -- If all 9 cells are filled, prompt to start a new game
    if number_of_moves_data = 9 then
        perform update_status('Game is over! Start a new game.');
        return;
    end if;

    -- Validate that mark is not NULL
    if mark is null then
        perform update_status('Mark cannot be NULL');
        return;
    end if;

    -- Convert mark to uppercase
    mark := upper(mark);

    -- Validate that mark is either 'X' or 'O'
    if mark not in ('X', 'O') then
        perform update_status('Mark must be X or O');
        return;
    end if;

    -- First move must be 'X'
    if number_of_moves_data = 0 and mark != 'X' then
        perform update_status('First move must be X');
        return;
    end if;

    -- Validate that players alternate turns
    if number_of_moves_data > 0 and mark = last_move_data then
        perform update_status('It''s not your turn!');
        return;
    end if;

    -- Validate that coordinates are within range
    if row_num not between 1 and 3 or col_num not between 1 and 3 then
        perform update_status('Row and column numbers must be between 1 and 3');
        return;
    end if;

    -- Determine the board row (x1, x2, x3)
    row_id := 'x' || row_num;

    -- Attempt to place the mark in the chosen cell
    update game_board as g
    set 
        y1 = case when col_num = 1 then mark else g.y1 end,
        y2 = case when col_num = 2 then mark else g.y2 end,
        y3 = case when col_num = 3 then mark else g.y3 end
    where g.id = row_id 
    and ( (col_num = 1 and g.y1 is null) 
       or (col_num = 2 and g.y2 is null) 
       or (col_num = 3 and g.y3 is null) );

    -- Check whether the move was successfully made
    if found then
        -- Update validation with the latest move
        update validation
        set last_move = mark, number_of_moves = number_of_moves + 1
        where validation.id = 1;

        -- Refresh the move count
        select number_of_moves into number_of_moves_data from validation where validation.id = 1;

        -- Check for a winner (all 8 winning combinations)
        SELECT w.mark INTO winner
        FROM (
            -- Rows
            SELECT y1 AS mark FROM game_board WHERE id = 'x1' AND y1 IS NOT NULL AND y1 = y2 AND y2 = y3
            UNION ALL
            SELECT y1 FROM game_board WHERE id = 'x2' AND y1 IS NOT NULL AND y1 = y2 AND y2 = y3
            UNION ALL
            SELECT y1 FROM game_board WHERE id = 'x3' AND y1 IS NOT NULL AND y1 = y2 AND y2 = y3
            UNION ALL
            -- Columns
            SELECT g1.y1 FROM game_board g1, game_board g2, game_board g3
                WHERE g1.id = 'x1' AND g2.id = 'x2' AND g3.id = 'x3'
                AND g1.y1 IS NOT NULL AND g1.y1 = g2.y1 AND g2.y1 = g3.y1
            UNION ALL
            SELECT g1.y2 FROM game_board g1, game_board g2, game_board g3
                WHERE g1.id = 'x1' AND g2.id = 'x2' AND g3.id = 'x3'
                AND g1.y2 IS NOT NULL AND g1.y2 = g2.y2 AND g2.y2 = g3.y2
            UNION ALL
            SELECT g1.y3 FROM game_board g1, game_board g2, game_board g3
                WHERE g1.id = 'x1' AND g2.id = 'x2' AND g3.id = 'x3'
                AND g1.y3 IS NOT NULL AND g1.y3 = g2.y3 AND g2.y3 = g3.y3
            UNION ALL
            -- Diagonals
            SELECT g1.y1 FROM game_board g1, game_board g2, game_board g3
                WHERE g1.id = 'x1' AND g2.id = 'x2' AND g3.id = 'x3'
                AND g1.y1 IS NOT NULL AND g1.y1 = g2.y2 AND g2.y2 = g3.y3
            UNION ALL
            SELECT g1.y3 FROM game_board g1, game_board g2, game_board g3
                WHERE g1.id = 'x1' AND g2.id = 'x2' AND g3.id = 'x3'
                AND g1.y3 IS NOT NULL AND g1.y3 = g2.y2 AND g2.y2 = g3.y1
        ) w
        LIMIT 1;

        -- Update status if there is a winner
        IF winner IS NOT NULL THEN
            UPDATE validation SET status = winner || ' wins! Start a new game.' WHERE id = 1;
        -- Check for a draw
        ELSIF number_of_moves_data = 9 THEN
            UPDATE validation SET status = 'It''s a draw! Start a new game.' WHERE id = 1;
        END IF;

    else
        perform update_status('Cell is already occupied.');
        return;
    end if;

    -- Display the board with the current game status
    return query 
        with game_data as (
            select 
                COALESCE(b.y1, ' ') || ' | ' || 
                COALESCE(b.y2, ' ') || ' | ' || 
                COALESCE(b.y3, ' ') as row_text,  
                b.id
            from game_board b
        ),
        status_cte as (  
            select status as current_status from validation where id = 1  
        )
        select row_text, NULL::TEXT, NULL::TEXT, NULL::TEXT as game_status from game_data where id = 'x1'
        union all
        select row_text, NULL::TEXT, NULL::TEXT, NULL::TEXT from game_data where id = 'x2'
        union all
        select row_text, NULL::TEXT, NULL::TEXT, NULL::TEXT from game_data where id = 'x3'
        union all
        select ''::TEXT, ''::TEXT, ''::TEXT, (select current_status from status_cte);

end;
$$ language plpgsql;


--drop function if exists newgame();
--drop function if exists update_status(text);
--drop function if exists nextmove(integer, integer, character);

--drop table if exists game_board;
--drop table if exists validation;

-- select * from game_board order by id;
-- select * from validation;

-- Test 1: X wins by diagonal (top-left to bottom-right)
select newgame();
select nextmove(1, 1, 'x'::char); -- X at (1,1)
select nextmove(1, 2, 'o'::char); -- O at (1,2)
select nextmove(2, 2, 'x'::char); -- X at (2,2)
select nextmove(1, 3, 'o'::char); -- O at (1,3)
select nextmove(3, 3, 'x'::char); -- X at (3,3) — X wins!

-- Test 2: Draw
-- Board result:
-- X | O | X
-- X | X | O
-- O | X | O
select newgame();
select nextmove(1, 1, 'x'::char);
select nextmove(1, 2, 'o'::char);
select nextmove(1, 3, 'x'::char);
select nextmove(2, 3, 'o'::char);
select nextmove(2, 1, 'x'::char);
select nextmove(3, 1, 'o'::char);
select nextmove(2, 2, 'x'::char);
select nextmove(3, 3, 'o'::char);
select nextmove(3, 2, 'x'::char); -- 9th move, no winner -> Draw!


-- Additional validation tests
-- Test 3: Error handling - wrong turn, occupied cell, out of range
select newgame();
select nextmove(1, 1, 'o'::char); -- Error: first move must be X
select nextmove(1, 1, 'x'::char); -- OK
select nextmove(1, 1, 'o'::char); -- Error: cell occupied
select nextmove(5, 5, 'o'::char); -- Error: out of range
select nextmove(1, 2, 'x'::char); -- Error: not your turn
select nextmove(1, 2, 'o'::char); -- OK