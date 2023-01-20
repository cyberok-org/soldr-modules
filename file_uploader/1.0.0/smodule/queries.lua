local Queries = {}

Queries.__index = Queries

function newQueries()
    local q = {}
    setmetatable(q, Queries)

    return q
end

function Queries:create_table(t, fields)
    local table_fields = {}
    for field, ftype in pairs(fields) do
        table.insert(table_fields, field .. " " .. ftype)
    end
    table.sort(table_fields)

    return [[
        CREATE TABLE IF NOT EXISTS ]] .. t .. [[ (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ]] .. table.concat(table_fields, ", ") .. [[
        );
    ]]
end

function Queries:get_incomplete_upload()
    return [[
        select
            f.id
            , f.uuid
            , f.time
            , f.filename
            , f.filesize
            , f.md5_hash
            , f.sha256_hash
            , f.local_path
            , fa.upload_response
            , fa.upload_code
            , f.agent_id
            , f.group_id
        from files f
        left join file_action fa on f.id = fa.file_id
        where f.group_id = ? and fa.result = ?
        order by f.id desc;
    ]]
end

function Queries:get_file_for_upload(t)
    return [[
        select
            id
            , uuid
            , filename
            , local_path
        from ]] .. t .. [[
        where
            filename = ?
            and md5_hash = ?
            and sha256_hash = ?;
    ]]
end

function Queries:get_file_info_by_uuid(t, fields)
    return [[
        SELECT ]] .. table.concat(fields, ", ") .. [[
        FROM ]] .. t .. [[
        WHERE uuid LIKE ?;
    ]]
end

function Queries:get_file_info_by_hash(t)
    return [[
        SELECT
            uuid
            , time
            , filename
            , filesize
            , md5_hash
            , sha256_hash
            , local_path
            , agent_id
            , group_id
        FROM ]] .. t .. [[
        WHERE md5_hash LIKE ? OR sha256_hash LIKE ?
        ORDER BY time DESC;
    ]]
end

function Queries:check_duplicate_file_by_hash(t)
    return [[
        SELECT filename, filesize, md5_hash, sha256_hash
        FROM ]] .. t .. [[
        WHERE (md5_hash LIKE ? OR sha256_hash LIKE ?) AND
            time >= datetime('now', '-7 days')
        ORDER BY time DESC;
    ]]
end

function Queries:get_uploaded_files(t, fields)
    return [[
        SELECT ]] .. table.concat(fields, ", ") .. [[
        FROM ]] .. t .. [[
        ORDER BY time DESC;
    ]]
end

function Queries:put_file(t, fields)
    local prepositions = {}
    for _=1,#fields do
        table.insert(prepositions, "?")
    end
    return [[
        INSERT OR IGNORE INTO ]] .. t .. [[ (
        ]] .. table.concat(fields, ", ") .. [[
        ) VALUES (
            ]] .. table.concat(prepositions, ", ") .. [[
        );
    ]]
end

function Queries:GetFileFromFilename(t)
    return [[
        select id, uuid, filename, filesize, md5_hash, sha256_hash, local_path
        from ]] .. t .. [[
        where filename = ?
        order by time DESC;
    ]]
end

function Queries:upload_file_resp(t)
    return [[
        UPDATE ]] .. t .. [[ SET
            upload_code = ?,
            upload_response = ?,
            result = ?
        WHERE file_id = ? and (result = ? or result = ?);
    ]]
end

function Queries:set_file_action(t)
    return [[
        INSERT INTO ]] .. t .. [[ (
            file_id, action, result
        ) VALUES (
            ?, ?, ?
        );
    ]]
end
