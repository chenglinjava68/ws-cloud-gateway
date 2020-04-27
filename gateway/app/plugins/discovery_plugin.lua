--
-- Licensed to the Apache Software Foundation (ASF) under one or more
-- contributor license agreements.  See the NOTICE file distributed with
-- this work for additional information regarding copyright ownership.
-- The ASF licenses this file to You under the Apache License, Version 2.0
-- (the "License"); you may not use this file except in compliance with
-- the License.  You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--
local log = require("app.core.log")
local route_store = require("app.store.route_store")
local discovery_stroe = require("app.store.discovery_stroe")
local balancer = require "ngx.balancer"
local resty_roundrobin = require "resty.roundrobin"
local str_tils = require("app.utils.str_utils")
local ngx = ngx

local _M = {
    name = "discovery",
    desc = "服务发现插件",
    version = 1.0
}

function _M.do_in_init_worker()
    route_store.init()
    discovery_stroe.init()
end

function _M.do_in_rewrite(route)
    local ngx_ctx = ngx.ctx
    local var = ngx.var

    local service_name = route.service_name
    var.target_service_name = service_name

    local service_nodes = discovery_stroe.get_service_nodes(service_name)
    local node_not_found_resp = route.props.discovery_node_not_found_resp or "no server node start"

    if not service_nodes then
        log.error("no server node start, uri: ", var.uri)
        ngx.say(node_not_found_resp)
        ngx.exit(500)
    end

    ngx_ctx.upstream_server_list = service_nodes
end

function _M.do_in_balancer()
    local ngx_ctx = ngx.ctx
    local server_list = ngx_ctx.upstream_server_list

    log.info("server list: ", str_tils.table_to_string(server_list))
    local rr_up = resty_roundrobin:new(server_list)
    local server = rr_up:find()
    balancer.set_current_peer(server)
end

return _M
