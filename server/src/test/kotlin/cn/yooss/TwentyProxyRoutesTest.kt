package cn.yooss

import io.ktor.client.HttpClient
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.MockRequestHandleScope
import io.ktor.client.engine.mock.respond
import io.ktor.client.engine.mock.toByteArray
import io.ktor.client.request.HttpRequestData
import io.ktor.client.request.HttpResponseData
import io.ktor.client.request.delete
import io.ktor.client.request.get
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.client.statement.bodyAsText
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.contentType
import io.ktor.http.headersOf
import io.ktor.server.testing.testApplication
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class TwentyProxyRoutesTest {

    private val companiesResponse =
        """{"data":{"companies":{"edges":[{"node":{"id":"c1","name":"Notion"}},
            {"node":{"id":"c2","name":"Stripe"}}],
            "pageInfo":{"endCursor":"x","hasNextPage":false}}}}"""

    private fun mockUpstream(
        handler: suspend MockRequestHandleScope.(HttpRequestData) -> HttpResponseData,
    ) {
        val engine = MockEngine { request -> handler(request) }
        TwentyProxySettings.client = HttpClient(engine)
        TwentyProxySettings.baseUrl = "http://upstream"
        TwentyProxySettings.apiToken = "test-token"
    }

    @Test
    fun `health 转发并带令牌`() = testApplication {
        application { module() }
        var sawAuth = false
        mockUpstream { request ->
            sawAuth = request.headers[HttpHeaders.Authorization] == "Bearer test-token"
            respond(
                """{"status":"ok"}""",
                HttpStatusCode.OK,
                headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val response = client.get("/api/twenty/health")
        assertEquals(HttpStatusCode.OK, response.status)
        assertTrue(sawAuth)
        assertEquals("""{"status":"ok"}""", response.bodyAsText())
    }

    @Test
    fun `列表代理返回计数与条目并构造复数查询`() = testApplication {
        application { module() }
        var sentQuery = ""
        mockUpstream { request ->
            sentQuery = request.body.toByteArray().decodeToString()
            respond(
                companiesResponse,
                HttpStatusCode.OK,
                headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val response = client.get("/api/twenty/objects/company?limit=10")
        assertEquals(HttpStatusCode.OK, response.status)
        assertTrue(sentQuery.contains("companies"), "查询应使用复数字段 companies：$sentQuery")
        val body = response.bodyAsText()
        assertTrue(body.contains("\"count\":2"), body)
        assertTrue(body.contains("Notion"), body)
        assertTrue(body.contains("Stripe"), body)
    }

    @Test
    fun `search 在内存过滤名称`() = testApplication {
        application { module() }
        mockUpstream {
            respond(
                companiesResponse,
                HttpStatusCode.OK,
                headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val response = client.get("/api/twenty/objects/company?search=Notion")
        val body = response.bodyAsText()
        assertTrue(body.contains("\"count\":1"), body)
        assertTrue(body.contains("Notion"), body)
        assertTrue(!body.contains("Stripe"), body)
    }

    @Test
    fun `创建代理转发 mutation 并返回创建结果`() = testApplication {
        application { module() }
        var sentQuery = ""
        mockUpstream { request ->
            sentQuery = request.body.toByteArray().decodeToString()
            respond(
                """{"data":{"createCompany":{"id":"new-1","name":"新公司"}}}""",
                HttpStatusCode.OK,
                headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val response = client.post("/api/twenty/objects/company") {
            contentType(io.ktor.http.ContentType.Application.Json)
            setBody("""{"name":"新公司"}""")
        }
        assertEquals(HttpStatusCode.OK, response.status)
        assertTrue(sentQuery.contains("createCompany"), sentQuery)
        val body = response.bodyAsText()
        assertTrue(body.contains("new-1"), body)
    }

    @Test
    fun `删除代理转发 mutation`() = testApplication {
        application { module() }
        var sentQuery = ""
        mockUpstream { request ->
            sentQuery = request.body.toByteArray().decodeToString()
            respond(
                """{"data":{"deleteCompany":{"id":"del-1"}}}""",
                HttpStatusCode.OK,
                headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val response = client.delete("/api/twenty/objects/company/del-1")
        assertEquals(HttpStatusCode.OK, response.status)
        assertTrue(sentQuery.contains("deleteCompany"), sentQuery)
        assertTrue(sentQuery.contains("del-1"), sentQuery)
    }

    @Test
    fun `上游 500 透传状态码`() = testApplication {
        application { module() }
        mockUpstream {
            respond(
                """{"error":"boom"}""",
                HttpStatusCode.InternalServerError,
                headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val response = client.get("/api/twenty/health")
        assertEquals(HttpStatusCode.InternalServerError, response.status)
    }

    @Test
    fun `custom 对象直接使用对象名作为查询字段`() = testApplication {
        application { module() }
        var sentQuery = ""
        mockUpstream { request ->
            sentQuery = request.body.toByteArray().decodeToString()
            respond(
                """{"data":{"contractsHeTongGuanLi":{"edges":[],
                    "pageInfo":{"endCursor":null,"hasNextPage":false}}}}""",
                HttpStatusCode.OK,
                headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val response = client.get("/api/twenty/objects/contractsHeTongGuanLi")
        assertEquals(HttpStatusCode.OK, response.status)
        assertTrue(sentQuery.contains("contractsHeTongGuanLi"), sentQuery)
    }
}
