using System.Net.Http;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using StaticBlazorSnomed.Models;

namespace StaticBlazorSnomed.Services
{
    public class AzureFunctionService
    {
        private readonly HttpClient _httpClient;
        private const string AzureFunctionBaseUrl = "https://snomed-viewer-function.azurewebsites.net/api/";

        public AzureFunctionService(HttpClient httpClient)
        {
            _httpClient = httpClient;
        }

        public async Task<List<SnomedModel>> GetSnomedDataAsync(string searchTerm = "")
        {
            try
            {
                var url = $"{AzureFunctionBaseUrl}snomed-search?term={Uri.EscapeDataString(searchTerm)}";
                var response = await _httpClient.GetAsync(url);
                
                if (response.IsSuccessStatusCode)
                {
                    var result = await response.Content.ReadFromJsonAsync<List<SnomedModel>>();
                    return result ?? new List<SnomedModel>();
                }
                else
                {
                    throw new HttpRequestException($"Request failed with status: {response.StatusCode}");
                }
            }
            catch (Exception ex)
            {
                // Log error or handle appropriately
                Console.WriteLine($"Error calling Azure Function: {ex.Message}");
                throw;
            }
        }

        public async Task<SnomedModel?> GetSnomedByIdAsync(string conceptId)
        {
            try
            {
                var url = $"{AzureFunctionBaseUrl}snomed-concept/{conceptId}";
                var response = await _httpClient.GetAsync(url);
                
                if (response.IsSuccessStatusCode)
                {
                    return await response.Content.ReadFromJsonAsync<SnomedModel>();
                }
                else if (response.StatusCode == System.Net.HttpStatusCode.NotFound)
                {
                    return null;
                }
                else
                {
                    throw new HttpRequestException($"Request failed with status: {response.StatusCode}");
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error calling Azure Function: {ex.Message}");
                throw;
            }
        }

        public async Task<T?> CallAzureFunctionAsync<T>(string functionEndpoint, object? requestData = null)
        {
            try
            {
                var url = $"{AzureFunctionBaseUrl}{functionEndpoint}";
                Console.WriteLine($"Full Azure Function URL: {url}");
                
                HttpResponseMessage response;
                if (requestData != null)
                {
                    var json = JsonSerializer.Serialize(requestData);
                    var content = new StringContent(json, Encoding.UTF8, "application/json");
                    response = await _httpClient.PostAsync(url, content);
                }
                else
                {
                    response = await _httpClient.GetAsync(url);
                }

                Console.WriteLine($"Response Status: {response.StatusCode}");
                Console.WriteLine($"Response Success: {response.IsSuccessStatusCode}");

                if (response.IsSuccessStatusCode)
                {
                    var responseContent = await response.Content.ReadAsStringAsync();
                    Console.WriteLine($"Response Content Length: {responseContent.Length}");
                    Console.WriteLine($"Response Content Preview: {responseContent.Substring(0, Math.Min(200, responseContent.Length))}...");
                    
                    var result = await response.Content.ReadFromJsonAsync<T>();
                    Console.WriteLine($"Deserialized result type: {typeof(T).Name}");
                    if (result is System.Collections.IList list)
                    {
                        Console.WriteLine($"List count: {list.Count}");
                    }
                    return result;
                }
                else
                {
                    var errorContent = await response.Content.ReadAsStringAsync();
                    Console.WriteLine($"Error response: {errorContent}");
                    throw new HttpRequestException($"Request failed with status: {response.StatusCode}");
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error calling Azure Function: {ex.Message}");
                throw;
            }
        }

        public async Task<List<SnomedUsageData>> GetUsageDataAsync(string snomedCodes)
        {
            var encodedCodes = Uri.EscapeDataString(snomedCodes);

            var url = $"{AzureFunctionBaseUrl}getsnomeddata?codes={encodedCodes}";
            var response = await _httpClient.GetAsync(url);

            if (response.IsSuccessStatusCode)
            {
                var result = await response.Content.ReadFromJsonAsync<List<SnomedUsageData>>();
                return result ?? new List<SnomedUsageData>();
            }

            var errorContent = await response.Content.ReadAsStringAsync();
            throw new HttpRequestException($"Azure Function request failed with status {response.StatusCode}: {errorContent}");
        }

        private List<SnomedUsageData> GetMockUsageData(string snomedCodes)
        {
            var codes = snomedCodes.Split(',').Select(c => c.Trim()).ToList();
            var mockData = new List<SnomedUsageData>();

            foreach (var code in codes.Take(10)) // Limit to 10 codes for demo
            {
                var random = new Random(code.GetHashCode()); // Use code as seed for consistent data

                mockData.Add(new SnomedUsageData
                {
                    ConceptId = code,
                    Procedure = GetMockConceptName(code),
                    Usage_2024_25 = random.Next(0, 55000),
                    Usage_2023_24 = random.Next(0, 50000),
                    Usage_2022_23 = random.Next(0, 45000),
                    Usage_2021_22 = random.Next(0, 40000),
                    Usage_2020_21 = random.Next(0, 35000),
                    Usage_2019_20 = random.Next(0, 30000),
                    Usage_2018_19 = random.Next(0, 25000),
                    Usage_2017_18 = random.Next(0, 20000),
                    Usage_2016_17 = random.Next(0, 15000),
                    Usage_2015_16 = random.Next(0, 12000),
                    Usage_2014_15 = random.Next(0, 10000),
                    Usage_2013_14 = random.Next(0, 8000),
                    Usage_2012_13 = random.Next(0, 6000),
                    Usage_2011_12 = random.Next(0, 4000)
                });
            }

            return mockData;
        }

        private string GetMockConceptName(string conceptId)
        {
            var concepts = new Dictionary<string, string>
            {
                { "6561009", "Body mass index" },
                { "1022541000000152", "Total white cell count" },
                { "922731000000100", "Review of medication (procedure)" },
                { "760903007", "Medication review (procedure)" },
                { "394720003", "Asthma medication review (procedure)" },
                { "718017007", "Medication review with patient (procedure)" },
                { "610241000000107", "Medication review of medical notes (procedure)" },
                { "473219007", "Asthma medication review (procedure)" },
                { "728891000000108", "Medication review using (procedure)" },
                { "712843007", "Medication review without patient (procedure)" }
            };

            return concepts.ContainsKey(conceptId) ? concepts[conceptId] : $"Mock Concept {conceptId}";
        }

        private string GetMockProcedureName(string conceptId)
        {
            var procedures = new Dictionary<string, string>
            {
                { "6561009", "Review of medication (procedure)" },
                { "1022541000000152", "Dispensing review of use of medicines (procedure)" },
                { "922731000000100", "Review of medication (procedure)" },
                { "760903007", "Medication review (procedure)" },
                { "394720003", "Asthma medication review (procedure)" },
                { "718017007", "Medication review with patient (procedure)" },
                { "610241000000107", "Medication review of medical notes (procedure)" },
                { "473219007", "Depression medication review (procedure)" },
                { "728891000000108", "Diabetes medication review (procedure)" },
                { "712843007", "Medication review without patient (procedure)" }
            };

            return procedures.ContainsKey(conceptId) ? procedures[conceptId] : $"Mock Procedure for {conceptId} (England)";
        }

        /// <summary>
        /// Gets SNOMED code details from NHS Ontology API via Azure Function
        /// </summary>
        /// <param name="snomedCode">The SNOMED concept ID to look up</param>
        /// <returns>NHS API response with FSN and additional details</returns>
        public async Task<NHSSnomedResponse?> GetSnomedFromNHSAPIAsync(string snomedCode)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(snomedCode))
                {
                    throw new ArgumentException("SNOMED code cannot be empty", nameof(snomedCode));
                }

                // Validate SNOMED code format (should be numeric)
                if (!System.Text.RegularExpressions.Regex.IsMatch(snomedCode.Trim(), @"^\d+$"))
                {
                    throw new ArgumentException("SNOMED code must be numeric", nameof(snomedCode));
                }

                var encodedCode = Uri.EscapeDataString(snomedCode.Trim());
                var url = $"{AzureFunctionBaseUrl}getsnomedcodefromnhsapi?code={encodedCode}";
                
                var response = await _httpClient.GetAsync(url);
                
                if (response.IsSuccessStatusCode)
                {
                    var result = await response.Content.ReadFromJsonAsync<NHSSnomedResponse>();
                    return result;
                }
                else
                {
                    var errorContent = await response.Content.ReadAsStringAsync();
                    throw new HttpRequestException($"NHS API request failed with status: {response.StatusCode}. Error: {errorContent}");
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error calling NHS API Azure Function: {ex.Message}");
                throw;
            }
        }

        /// <summary>
        /// Gets SNOMED codes that match an ECL (Expression Constraint Language) query
        /// </summary>
        /// <param name="eclQuery">The ECL query expression</param>
        /// <returns>List of SNOMED concepts matching the ECL query</returns>
        public async Task<List<SnomedModel>> GetSnomedCodesFromECLAsync(string eclQuery)
        {
            var (results, _) = await GetSnomedCodesFromECLWithRawResponseAsync(eclQuery);
            return results;
        }

        /// <summary>
        /// Gets SNOMED codes that match an ECL query and returns raw response for version info
        /// </summary>
        /// <param name="eclQuery">The ECL query expression</param>
        /// <returns>Tuple of (results, rawResponse)</returns>
        public async Task<(List<SnomedModel> Results, string RawResponse)> GetSnomedCodesFromECLWithRawResponseAsync(string eclQuery)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(eclQuery))
                {
                    throw new ArgumentException("ECL query cannot be empty", nameof(eclQuery));
                }

                // Use POST for ECL queries to avoid URL length limitations (many SNOMED codes can exceed URL limits)
                var url = $"{AzureFunctionBaseUrl}getsnomedcodesfromecl";
                
                // Create JSON payload
                var requestBody = new { ecl = eclQuery.Trim() };
                var jsonContent = new StringContent(
                    System.Text.Json.JsonSerializer.Serialize(requestBody),
                    Encoding.UTF8,
                    "application/json"
                );
                
                Console.WriteLine($"Calling ECL endpoint (POST): {url}");
                Console.WriteLine($"ECL Query length: {eclQuery.Length} characters");
                
                var response = await _httpClient.PostAsync(url, jsonContent);
                var responseContent = await response.Content.ReadAsStringAsync();
                
                Console.WriteLine($"ECL Response Status: {response.StatusCode}");
                Console.WriteLine($"ECL Response Content Length: {responseContent.Length}");
                
                // Log first 1000 chars to see structure
                var preview = responseContent.Substring(0, Math.Min(1000, responseContent.Length));
                Console.WriteLine($"ECL Response Preview: {preview}");
                
                if (!response.IsSuccessStatusCode)
                {
                    throw new HttpRequestException($"ECL query failed with status: {response.StatusCode}. Response: {responseContent}");
                }

                // Try to parse as direct array first
                try
                {
                    var directResult = await response.Content.ReadFromJsonAsync<List<SnomedModel>>();
                    if (directResult != null && directResult.Any())
                    {
                        Console.WriteLine($"Successfully parsed {directResult.Count} results");
                        var first = directResult[0];
                        Console.WriteLine($"First result - ConceptId: '{first.ConceptId}', Term: '{first.Term}', FSN: '{first.FullySpecifiedName}', Active: {first.IsActive}");
                        
                        // Check if data is actually populated
                        if (string.IsNullOrEmpty(first.ConceptId) && string.IsNullOrEmpty(first.Term))
                        {
                            Console.WriteLine("WARNING: Parsed objects but properties are empty - checking raw JSON structure...");
                            
                            // Parse as generic JSON to see actual property names
                            using var rawDoc = System.Text.Json.JsonDocument.Parse(responseContent);
                            if (rawDoc.RootElement.ValueKind == System.Text.Json.JsonValueKind.Array && rawDoc.RootElement.GetArrayLength() > 0)
                            {
                                var firstElement = rawDoc.RootElement[0];
                                Console.WriteLine($"First element properties: {string.Join(", ", firstElement.EnumerateObject().Select(p => $"{p.Name}={p.Value}"))}");
                            }
                        }
                        
                        return (directResult, responseContent);
                    }
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"Failed to parse as List<SnomedModel>: {ex.Message}, trying wrapper object...");
                }

                // Try to parse as wrapped response with different property names
                using var doc = System.Text.Json.JsonDocument.Parse(responseContent);
                var root = doc.RootElement;

                // Check for common wrapper properties
                if (root.TryGetProperty("concepts", out var concepts))
                {
                    // ECL query response format: { "ecl": "...", "totalResults": 244, "concepts": [...] }
                    // Each concept has: { "code": "...", "display": "...", "system": "..." }
                    var conceptsList = new List<SnomedModel>();
                    
                    foreach (var concept in concepts.EnumerateArray())
                    {
                        var model = new SnomedModel
                        {
                            ConceptId = concept.TryGetProperty("code", out var code) ? code.GetString() ?? "" : "",
                            Term = concept.TryGetProperty("display", out var display) ? display.GetString() ?? "" : "",
                            FullySpecifiedName = concept.TryGetProperty("display", out var fsn) ? fsn.GetString() ?? "" : "",
                            IsActive = true, // ECL queries typically return active concepts only
                            Id = concept.TryGetProperty("code", out var id) ? id.GetString() ?? "" : ""
                        };
                        conceptsList.Add(model);
                    }
                    
                    Console.WriteLine($"Mapped {conceptsList.Count} concepts from ECL response");
                    if (conceptsList.Any())
                    {
                        Console.WriteLine($"First mapped concept - ConceptId: '{conceptsList[0].ConceptId}', Term: '{conceptsList[0].Term}'");
                    }
                    
                    return (conceptsList, responseContent);
                }
                else if (root.TryGetProperty("items", out var items))
                {
                    var result = System.Text.Json.JsonSerializer.Deserialize<List<SnomedModel>>(items.GetRawText());
                    return (result ?? new List<SnomedModel>(), responseContent);
                }
                else if (root.TryGetProperty("results", out var results))
                {
                    var result = System.Text.Json.JsonSerializer.Deserialize<List<SnomedModel>>(results.GetRawText());
                    return (result ?? new List<SnomedModel>(), responseContent);
                }
                else if (root.TryGetProperty("error", out var error))
                {
                    throw new HttpRequestException($"Server returned error: {error.GetString()}");
                }
                
                // If we get here, we couldn't parse it
                throw new System.Text.Json.JsonException($"Unexpected JSON format. Response starts with: {responseContent.Substring(0, Math.Min(200, responseContent.Length))}");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error executing ECL query: {ex.Message}");
                throw;
            }
        }

        /// <summary>
        /// Searches Read codes to find SNOMED CT mappings via Azure Function
        /// </summary>
        /// <param name="readCodes">Single Read code or comma-separated list of Read codes</param>
        /// <returns>Search result with all mappings and replacement concepts</returns>
        public async Task<ReadCodeSearchResult> SearchReadCodesAsync(string readCodes)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(readCodes))
                {
                    throw new ArgumentException("Read codes cannot be empty", nameof(readCodes));
                }

                var encodedCodes = Uri.EscapeDataString(readCodes.Trim());
                var url = $"{AzureFunctionBaseUrl}search?codes={encodedCodes}";
                
                Console.WriteLine($"Calling Read Code search endpoint: {url}");
                
                var response = await _httpClient.GetAsync(url);
                var responseContent = await response.Content.ReadAsStringAsync();
                
                Console.WriteLine($"Read Code Search Response Status: {response.StatusCode}");
                Console.WriteLine($"Response Content Length: {responseContent.Length}");
                Console.WriteLine($"Response Content Preview: {responseContent.Substring(0, Math.Min(500, responseContent.Length))}");
                
                if (!response.IsSuccessStatusCode)
                {
                    throw new HttpRequestException($"Read code search failed with status: {response.StatusCode}. Response: {responseContent}");
                }

                // Try to parse the response
                var result = System.Text.Json.JsonSerializer.Deserialize<ReadCodeSearchResult>(responseContent, new System.Text.Json.JsonSerializerOptions
                {
                    PropertyNameCaseInsensitive = true
                });

                Console.WriteLine($"Deserialized result - TotalMappings: {result?.TotalMappings}, Mappings count: {result?.Mappings?.Count ?? 0}");
                
                return result ?? new ReadCodeSearchResult();
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error searching Read codes: {ex.Message}");
                throw;
            }
        }

        // ============================================================================
        // LOCAL SERVER SNOMED HIERARCHY ENDPOINTS
        // These methods call the local SNOMED CT server for hierarchy visualization
        // ============================================================================

        private const string LocalServerBaseUrl = "http://localhost:5000/api/";

        /// <summary>
        /// Gets all ancestors (parents, grandparents, etc.) for a SNOMED CT concept
        /// </summary>
        /// <param name="conceptId">The SNOMED CT concept ID</param>
        /// <returns>List of ancestor nodes</returns>
        public async Task<List<SnomedHierarchyNode>> GetAncestorsAsync(string conceptId)
        {
            try
            {
                var url = $"{LocalServerBaseUrl}ancestors/{Uri.EscapeDataString(conceptId)}";
                Console.WriteLine($"Calling ancestors endpoint: {url}");
                
                var response = await _httpClient.GetAsync(url);
                
                if (response.IsSuccessStatusCode)
                {
                    var result = await response.Content.ReadFromJsonAsync<List<SnomedHierarchyNode>>();
                    return result ?? new List<SnomedHierarchyNode>();
                }
                else
                {
                    var errorContent = await response.Content.ReadAsStringAsync();
                    Console.WriteLine($"Ancestors request failed: {response.StatusCode} - {errorContent}");
                    throw new HttpRequestException($"Failed to get ancestors: {response.StatusCode}");
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error getting ancestors: {ex.Message}");
                throw;
            }
        }

        /// <summary>
        /// Gets all descendants (children, grandchildren, etc.) for a SNOMED CT concept
        /// </summary>
        /// <param name="conceptId">The SNOMED CT concept ID</param>
        /// <param name="maxDepth">Maximum depth to traverse (default 3)</param>
        /// <returns>List of descendant nodes</returns>
        public async Task<List<SnomedHierarchyNode>> GetDescendantsAsync(string conceptId, int maxDepth = 3)
        {
            try
            {
                var url = $"{LocalServerBaseUrl}descendants/{Uri.EscapeDataString(conceptId)}?maxDepth={maxDepth}";
                Console.WriteLine($"Calling descendants endpoint: {url}");
                
                var response = await _httpClient.GetAsync(url);
                
                if (response.IsSuccessStatusCode)
                {
                    var result = await response.Content.ReadFromJsonAsync<List<SnomedHierarchyNode>>();
                    return result ?? new List<SnomedHierarchyNode>();
                }
                else
                {
                    var errorContent = await response.Content.ReadAsStringAsync();
                    Console.WriteLine($"Descendants request failed: {response.StatusCode} - {errorContent}");
                    throw new HttpRequestException($"Failed to get descendants: {response.StatusCode}");
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error getting descendants: {ex.Message}");
                throw;
            }
        }

        /// <summary>
        /// Gets the full hierarchy (ancestors and descendants) for a SNOMED CT concept
        /// </summary>
        /// <param name="conceptId">The SNOMED CT concept ID</param>
        /// <param name="ancestorDepth">Maximum ancestor depth (default all)</param>
        /// <param name="descendantDepth">Maximum descendant depth (default 2)</param>
        /// <returns>Complete hierarchy response</returns>
        public async Task<SnomedHierarchyResponse> GetSnomedHierarchyAsync(string conceptId, int? ancestorDepth = null, int descendantDepth = 2)
        {
            try
            {
                var url = $"{LocalServerBaseUrl}hierarchy/{Uri.EscapeDataString(conceptId)}?descendantDepth={descendantDepth}";
                if (ancestorDepth.HasValue)
                {
                    url += $"&ancestorDepth={ancestorDepth.Value}";
                }
                
                Console.WriteLine($"Calling hierarchy endpoint: {url}");
                
                var response = await _httpClient.GetAsync(url);
                
                if (response.IsSuccessStatusCode)
                {
                    var result = await response.Content.ReadFromJsonAsync<SnomedHierarchyResponse>();
                    return result ?? new SnomedHierarchyResponse();
                }
                else
                {
                    var errorContent = await response.Content.ReadAsStringAsync();
                    Console.WriteLine($"Hierarchy request failed: {response.StatusCode} - {errorContent}");
                    return new SnomedHierarchyResponse { Error = $"Failed to get hierarchy: {response.StatusCode}" };
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error getting hierarchy: {ex.Message}");
                return new SnomedHierarchyResponse { Error = ex.Message };
            }
        }

        /// <summary>
        /// Gets direct parents (immediate IS-A relationships) for a SNOMED CT concept
        /// </summary>
        /// <param name="conceptId">The SNOMED CT concept ID</param>
        /// <returns>List of direct parent nodes</returns>
        public async Task<List<SnomedHierarchyNode>> GetDirectParentsAsync(string conceptId)
        {
            try
            {
                var url = $"{LocalServerBaseUrl}parents/{Uri.EscapeDataString(conceptId)}";
                Console.WriteLine($"Calling parents endpoint: {url}");
                
                var response = await _httpClient.GetAsync(url);
                
                if (response.IsSuccessStatusCode)
                {
                    var result = await response.Content.ReadFromJsonAsync<List<SnomedHierarchyNode>>();
                    return result ?? new List<SnomedHierarchyNode>();
                }
                else
                {
                    throw new HttpRequestException($"Failed to get parents: {response.StatusCode}");
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error getting parents: {ex.Message}");
                throw;
            }
        }

        /// <summary>
        /// Gets direct children (immediate IS-A relationships) for a SNOMED CT concept
        /// </summary>
        /// <param name="conceptId">The SNOMED CT concept ID</param>
        /// <returns>List of direct child nodes</returns>
        public async Task<List<SnomedHierarchyNode>> GetDirectChildrenAsync(string conceptId)
        {
            try
            {
                var url = $"{LocalServerBaseUrl}children/{Uri.EscapeDataString(conceptId)}";
                Console.WriteLine($"Calling children endpoint: {url}");
                
                var response = await _httpClient.GetAsync(url);
                
                if (response.IsSuccessStatusCode)
                {
                    var result = await response.Content.ReadFromJsonAsync<List<SnomedHierarchyNode>>();
                    return result ?? new List<SnomedHierarchyNode>();
                }
                else
                {
                    throw new HttpRequestException($"Failed to get children: {response.StatusCode}");
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error getting children: {ex.Message}");
                throw;
            }
        }
    }
}
