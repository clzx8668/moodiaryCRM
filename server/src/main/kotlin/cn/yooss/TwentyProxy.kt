package cn.yooss

import io.ktor.client.HttpClient
import io.ktor.client.engine.cio.CIO
import io.ktor.client.request.bearerAuth
import io.ktor.client.request.delete
import io.ktor.client.request.get
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.client.statement.bodyAsText
import io.ktor.http.ContentType
import io.ktor.http.HttpStatusCode
import io.ktor.http.contentType
import io.ktor.server.application.Application
import io.ktor.server.request.receive
import io.ktor.server.response.respond
import io.ktor.server.response.respondText
import io.ktor.server.routing.get
import io.ktor.server.routing.post
import io.ktor.server.routing.delete
import io.ktor.server.routing.route
import io.ktor.server.routing.routing
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put

/**
 * Twenty CRM 反向代理（供桌面端/脚本无令牌直连时使用）。
 *
 * 环境变量：
 * - TWENTY_BASE_URL：默认 http://10.200.245.54:3000
 * - TWENTY_API_TOKEN：必填，Twenty API Key
 *
 * 上游 429/5xx 透传状态码，不做重试（重试策略在 Flutter 客户端）。
 */
object TwentyProxySettings {
    var baseUrl: String = System.getenv("TWENTY_BASE_URL") ?: "http://10.200.245.54:3000"
    var apiToken: String = System.getenv("TWENTY_API_TOKEN") ?: ""
    var client: HttpClient = HttpClient(CIO)
}

fun Application.twentyProxyRoutes() {
    routing {
        route("/api/twenty") {
            get("/health") {
                val upstream = TwentyProxySettings.client.get("${TwentyProxySettings.baseUrl}/healthz") {
                    if (TwentyProxySettings.apiToken.isNotBlank()) {
                        bearerAuth(TwentyProxySettings.apiToken)
                    }
                }
                call.respondText(
                    upstream.bodyAsText(),
                    ContentType.Application.Json,
                    upstream.status,
                )
            }

            get("/objects/{object}") {
                val objectName = call.parameters["object"]
                    ?: return@get call.respond(HttpStatusCode.BadRequest, mapOf("error" to "缺少 object"))
                val limit = call.request.queryParameters["limit"]?.toIntOrNull()?.coerceAtMost(200) ?: 100
                val search = call.request.queryParameters["search"]
                val field = pluralField(objectName)
                val query =
                    "query { $field(first: $limit) { edges { node { id name } } " +
                        "pageInfo { endCursor hasNextPage } } }"
                val result = upstreamGraphql(query)
                if (result.error != null) {
                    return@get call.respondText(result.error, ContentType.Application.Json, result.status)
                }
                val objectData = result.body["data"]?.jsonObject?.get(field)?.jsonObject
                val edges = objectData?.get("edges")?.jsonArray ?: JsonArray(emptyList())
                val items = edges.mapNotNull { it.jsonObject["node"]?.jsonObject }.filter { node ->
                    search.isNullOrBlank() ||
                        node["name"]?.jsonPrimitive?.contentOrNull
                            ?.contains(search, ignoreCase = true) == true
                }
                val responseBody = buildJsonObject {
                    put("object", objectName)
                    put("count", items.size)
                    put("items", JsonArray(items))
                }
                call.respondText(responseBody.toString(), ContentType.Application.Json)
            }

            post("/objects/{object}") {
                val objectName = call.parameters["object"]
                    ?: return@post call.respond(HttpStatusCode.BadRequest, mapOf("error" to "缺少 object"))
                val data = call.receive<JsonObject>()
                val className = objectName.replaceFirstChar { it.uppercase() }
                val literal = jsonToGraphQlLiteral(data)
                val query = "mutation { create$className(data: $literal) { id name } }"
                val result = upstreamGraphql(query)
                if (result.error != null) {
                    return@post call.respondText(result.error, ContentType.Application.Json, result.status)
                }
                val created = result.body["data"]?.jsonObject?.get("create$className")
                call.respondText(created.toString(), ContentType.Application.Json)
            }

            delete("/objects/{object}/{id}") {
                val objectName = call.parameters["object"]
                    ?: return@delete call.respond(HttpStatusCode.BadRequest, mapOf("error" to "缺少 object"))
                val id = call.parameters["id"]
                    ?: return@delete call.respond(HttpStatusCode.BadRequest, mapOf("error" to "缺少 id"))
                val className = objectName.replaceFirstChar { it.uppercase() }
                val query = "mutation { delete$className(id: \"$id\") { id } }"
                val result = upstreamGraphql(query)
                if (result.error != null) {
                    return@delete call.respondText(result.error, ContentType.Application.Json, result.status)
                }
                val deleted = result.body["data"]?.jsonObject?.get("delete$className")
                call.respondText(deleted.toString(), ContentType.Application.Json)
            }
        }
    }
}

private data class GraphQlResult(
    val body: JsonObject,
    val error: String? = null,
    val status: HttpStatusCode = HttpStatusCode.OK,
)

private suspend fun upstreamGraphql(query: String): GraphQlResult {
    val settings = TwentyProxySettings
    val payload = buildJsonObject {
        put("query", query)
    }
    val response = settings.client.post("${settings.baseUrl}/graphql") {
        contentType(ContentType.Application.Json)
        if (settings.apiToken.isNotBlank()) {
            bearerAuth(settings.apiToken)
        }
        setBody(payload.toString())
    }
    val text = response.bodyAsText()
    if (response.status.value >= 400) {
        return GraphQlResult(
            body = JsonObject(emptyMap()),
            error = text,
            status = response.status,
        )
    }
    val parsed = try {
        Json.parseToJsonElement(text).jsonObject
    } catch (_: Exception) {
        return GraphQlResult(
            body = JsonObject(emptyMap()),
            error = text,
            status = HttpStatusCode.BadGateway,
        )
    }
    parsed["errors"]?.let { errors ->
        if (errors is JsonArray && errors.isNotEmpty()) {
            return GraphQlResult(
                body = parsed,
                error = errors.toString(),
                status = HttpStatusCode.BadGateway,
            )
        }
    }
    return GraphQlResult(body = parsed)
}

private fun pluralField(objectName: String): String =
    when (objectName) {
        "person" -> "people"
        "company" -> "companies"
        "opportunity" -> "opportunities"
        "contractsHeTongGuanLi",
        "paymentsHuiKuanJiLu",
        "invoiceFaPiao",
        "commissionsTiChengJieSuan",
        -> objectName
        else -> "${objectName}s"
    }

/** 将 JsonObject 序列化为 GraphQL 字面量 */
private fun jsonToGraphQlLiteral(element: JsonElement): String =
    when (element) {
        is JsonNull -> "null"
        is JsonPrimitive -> {
            val content = element.content
            when {
                element.isString -> "\"${content.replace("\\", "\\\\").replace("\"", "\\\"")}\""
                content == "true" || content == "false" -> content
                else -> content
            }
        }
        is JsonObject -> element.entries.joinToString(
            prefix = "{",
            postfix = "}",
        ) { (k, v) -> "$k: ${jsonToGraphQlLiteral(v)}" }
        is JsonArray -> element.joinToString(
            prefix = "[",
            postfix = "]",
        ) { jsonToGraphQlLiteral(it) }
    }
