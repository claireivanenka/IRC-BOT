-- =====================================================================
-- Module Database - Connexion PostgreSQL via luasql
-- =====================================================================

local M = {}

function M.connect(user_config)
    local config = user_config
    
    -- Si on reçoit la table database directement, la transformer
    if config and config.database and not config.host then
        -- On a reçu config.database, il faut extraire les champs
        local db_config = config
        config = {
            database = db_config.database or db_config.dbname,
            user = db_config.user,
            password = db_config.password,
            host = db_config.host,
            port = db_config.port
        }
    end
    
    if not config then
        print("⚠️  Configuration PostgreSQL manquante")
        return nil
    end
    
    -- Essayer avec luasql.postgres
    local luasql_ok, luasql = pcall(require, "luasql.postgres")
    if luasql_ok then
        local env = luasql.postgres()
        if not env then
            print("⚠️  Impossible de créer l'environnement luasql.postgres")
            return nil
        end
        
        local conn, err = env:connect(
            config.database,
            config.user,
            config.password,
            config.host,
            config.port
        )
        
        if not conn then
            print("⚠️  Impossible de se connecter à PostgreSQL via luasql: " .. tostring(err))
            env:close()
            return nil
        end
        
        -- Retourner un wrapper pour compatibilité
        local wrapper = {
            connection = conn,
            env = env,
            type = "luasql",
            
            execute = function(self, query)
                local cursor_or_count, err = conn:execute(query)
                
                -- Pour les requêtes qui ne retournent pas de lignes (INSERT, UPDATE, CREATE, etc.)
                -- conn:execute() retourne un nombre (count de lignes affectées)
                if type(cursor_or_count) == "number" then
                    return {success = true, affected_rows = cursor_or_count}
                end
                
                if not cursor_or_count then
                    print("⚠️  Erreur SQL: " .. tostring(err))
                    return nil
                end
                
                -- Récupérer tous les résultats
                local results = {}
                local row = cursor_or_count:fetch({}, "a")
                while type(row) == "table" and next(row) ~= nil do
                    -- Convertir les booléens PostgreSQL (t/f) en booléens Lua
                    for k, v in pairs(row) do
                        if v == "t" then
                            row[k] = true
                        elseif v == "f" then
                            row[k] = false
                        end
                    end
                    table.insert(results, row)
                    row = cursor_or_count:fetch({}, "a")
                end
                cursor_or_count:close()
                
                -- Si c'est un SELECT avec des résultats
                if #results > 0 then
                    return results
                end
                
                -- Pour INSERT/UPDATE/DELETE, retourner true
                return {success = true}
            end,
            
            execute_single = function(self, query)
                local cursor, err = conn:execute(query)
                if not cursor then
                    return nil, err
                end
                
                local row = cursor:fetch({}, "a")
                cursor:close()
                
                -- Convertir les booléens PostgreSQL (t/f) en booléens Lua
                if row then
                    for k, v in pairs(row) do
                        if v == "t" then
                            row[k] = true
                        elseif v == "f" then
                            row[k] = false
                        end
                    end
                end
                
                return row
            end,
            
            escape = function(self, str)
                if not str then return "NULL" end
                return str:gsub("'", "''")
            end,
            
            close = function(self)
                if conn then
                    conn:close()
                    conn = nil
                end
                if env then
                    env:close()
                    env = nil
                end
            end,
            
            commit = function(self)
                -- luasql n'a pas de commit explicite, il est auto-commit par défaut
                return true
            end,
            
            rollback = function(self)
                -- Pas de rollback avec auto-commit
                return true
            end,
        }
        
        print("✓ Connecté à PostgreSQL via luasql.postgres")
        return wrapper
    end
    
    -- Essayer avec libpq (plus performant)
    local libpq_ok, libpq = pcall(require, "libpq")
    if libpq_ok then
        local conn, err = libpq.connect(
            "dbname=" .. config.database .. 
            " user=" .. config.user .. 
            " password=" .. config.password .. 
            " host=" .. config.host .. 
            " port=" .. config.port
        )
        
        if not conn then
            print("⚠️  Impossible de se connecter à PostgreSQL via libpq: " .. tostring(err))
            return nil
        end
        
        local wrapper = {
            connection = conn,
            type = "libpq",
            
            execute = function(self, query)
                local res, err = conn:exec(query)
                if not res then
                    print("⚠️  Erreur SQL: " .. tostring(err))
                    return nil
                end
                
                local results = {}
                if res:status() == "PGRES_TUPLES_OK" then
                    local num_rows = res:ntuples()
                    local num_cols = res:nfields()
                    
                    for i = 0, num_rows - 1 do
                        local row = {}
                        for j = 0, num_cols - 1 do
                            local col_name = res:fname(j)
                            local col_value = res:getvalue(i, j)
                            -- Convertir les booléens PostgreSQL (t/f) en booléens Lua
                            if col_value == "t" then
                                col_value = true
                            elseif col_value == "f" then
                                col_value = false
                            end
                            row[col_name] = col_value
                        end
                        table.insert(results, row)
                    end
                end
                
                res:clear()
                
                if #results > 0 then
                    return results
                end
                
                return {success = true}
            end,
            
            execute_single = function(self, query)
                local res, err = conn:exec(query)
                if not res then
                    return nil, err
                end
                
                local row = nil
                if res:status() == "PGRES_TUPLES_OK" and res:ntuples() > 0 then
                    row = {}
                    local num_cols = res:nfields()
                    for j = 0, num_cols - 1 do
                        local col_name = res:fname(j)
                        local col_value = res:getvalue(0, j)
                        -- Convertir les booléens PostgreSQL (t/f) en booléens Lua
                        if col_value == "t" then
                            col_value = true
                        elseif col_value == "f" then
                            col_value = false
                        end
                        row[col_name] = col_value
                    end
                end
                
                res:clear()
                return row
            end,
            
            escape = function(self, str)
                if not str then return "NULL" end
                -- LibPQ a son propre escape
                if conn then
                    return conn:escape_string(str)
                end
                return str:gsub("'", "''")
            end,
            
            close = function(self)
                if conn then
                    conn:finish()
                    conn = nil
                end
            end,
            
            commit = function(self)
                if conn then
                    return conn:exec("COMMIT"):status() == "PGRES_COMMAND_OK"
                end
                return true
            end,
            
            rollback = function(self)
                if conn then
                    return conn:exec("ROLLBACK"):status() == "PGRES_COMMAND_OK"
                end
                return true
            end,
        }
        
        print("✓ Connecté à PostgreSQL via libpq")
        return wrapper
    end
    
    -- Fallback: utiliser psql en ligne de commande (lent mais fonctionne)
    print("⚠️  Pas de bibliothèque Lua PostgreSQL trouvée, utilisation de psql en CLI")
    
    local wrapper = {
        type = "psql_cli",
        config = config,
        
        execute = function(self, query)
            local conn_string = string.format(
                "PGPASSWORD=%s psql -h %s -p %s -U %s -d %s -c \"%s\" -t -A -F',' 2>&1",
                config.password:gsub("'", "'\\''"),
                config.host,
                config.port,
                config.user,
                config.database,
                query:gsub("'", "'\\''")
            )
            
            local handle = io.popen(conn_string)
            if not handle then return nil end
            
            local result = handle:read("*a")
            handle:close()
            
            -- Parser le résultat CSV
            local lines = {}
            for line in result:gmatch("[^\n]+") do
                if line and line:trim() ~= "" then
                    table.insert(lines, line)
                end
            end
            
            if #lines > 0 then
                return {raw = result, lines = lines}
            end
            
            return {success = true}
        end,
        
        execute_single = function(self, query)
            local results = self:execute(query)
            if results and results.lines and #results.lines > 0 then
                return {raw = results.lines[1]}
            end
            return nil
        end,
        
        escape = function(self, str)
            if not str then return "NULL" end
            return str:gsub("'", "''")
        end,
        
        close = function(self)
            -- Rien à fermer
        end,
        
        commit = function(self)
            return true
        end,
        
        rollback = function(self)
            return true
        end,
    }
    
    return wrapper
end

return M
