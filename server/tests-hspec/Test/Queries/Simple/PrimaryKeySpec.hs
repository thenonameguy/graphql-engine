{-# LANGUAGE QuasiQuotes #-}

-- |
-- Accessing objects based on their primary keys.
--
-- https://hasura.io/docs/latest/queries/postgres/simple-object-queries/#fetch-an-object-using-its-primary-key
-- TODO: Add MSSQL link when it has been documented.
module Test.Queries.Simple.PrimaryKeySpec (spec) where

import Data.Aeson (Value)
import Data.List.NonEmpty qualified as NE
import Harness.Backend.Citus qualified as Citus
import Harness.Backend.Cockroach qualified as Cockroach
import Harness.Backend.Postgres qualified as Postgres
import Harness.Backend.Sqlserver qualified as Sqlserver
import Harness.GraphqlEngine (postGraphql)
import Harness.Quoter.Graphql (graphql)
import Harness.Quoter.Yaml (interpolateYaml)
import Harness.Test.Fixture qualified as Fixture
import Harness.Test.Schema (Table (..), table)
import Harness.Test.Schema qualified as Schema
import Harness.TestEnvironment (TestEnvironment)
import Harness.Yaml (shouldReturnYaml)
import Hasura.Prelude
import Test.Hspec (SpecWith, describe, it)

spec :: SpecWith TestEnvironment
spec =
  Fixture.run
    ( NE.fromList
        [ (Fixture.fixture $ Fixture.Backend Fixture.Postgres)
            { Fixture.setupTeardown = \(testEnvironment, _) ->
                [ Postgres.setupTablesAction schema testEnvironment
                ]
            },
          (Fixture.fixture $ Fixture.Backend Fixture.Citus)
            { Fixture.setupTeardown = \(testEnvironment, _) ->
                [ Citus.setupTablesAction schema testEnvironment
                ]
            },
          (Fixture.fixture $ Fixture.Backend Fixture.Cockroach)
            { Fixture.setupTeardown = \(testEnv, _) ->
                [ Cockroach.setupTablesAction schema testEnv
                ],
              Fixture.customOptions =
                Just $
                  Fixture.defaultOptions
                    { Fixture.stringifyNumbers = True,
                      Fixture.skipTests = Just "Cockroach disabled pending oid 114 fix https://github.com/hasura/graphql-engine-mono/issues/5984"
                    }
            },
          (Fixture.fixture $ Fixture.Backend Fixture.SQLServer)
            { Fixture.setupTeardown = \(testEnvironment, _) ->
                [ Sqlserver.setupTablesAction schema testEnvironment
                ]
            }
        ]
    )
    tests

--------------------------------------------------------------------------------
-- Schema

schema :: [Schema.Table]
schema =
  [ (table "authors")
      { tableColumns =
          [ Schema.column "id" Schema.TInt,
            Schema.column "name" Schema.TStr
          ],
        tablePrimaryKey = ["id"],
        tableData =
          [ [ Schema.VInt 1,
              Schema.VStr "Justin"
            ],
            [ Schema.VInt 2,
              Schema.VStr "Beltran"
            ],
            [ Schema.VInt 3,
              Schema.VStr "Sidney"
            ],
            [ Schema.VInt 4,
              Schema.VStr "Anjela"
            ]
          ]
      }
  ]

--------------------------------------------------------------------------------
-- Tests

tests :: Fixture.Options -> SpecWith TestEnvironment
tests opts = do
  let shouldBe :: IO Value -> Value -> IO ()
      shouldBe = shouldReturnYaml opts

  describe "Primary key queries" do
    it "Lookup with primary key" \testEnvironment -> do
      let schemaName :: Schema.SchemaName
          schemaName = Schema.getSchemaName testEnvironment

          actual :: IO Value
          actual =
            postGraphql
              testEnvironment
              [graphql|
                query {
                  #{schemaName}_authors_by_pk(id: 1) {
                    id
                    name
                  }
                }
              |]

          expected :: Value
          expected =
            [interpolateYaml|
              data:
                #{schemaName}_authors_by_pk:
                  id: 1
                  name: Justin
            |]

      actual `shouldBe` expected

    it "Lookup with (missing) primary key" \testEnvironment -> do
      let schemaName :: Schema.SchemaName
          schemaName = Schema.getSchemaName testEnvironment

          actual :: IO Value
          actual =
            postGraphql
              testEnvironment
              [graphql|
                query {
                  #{schemaName}_authors_by_pk(id: 5) {
                    id
                    name
                  }
                }
              |]

          expected :: Value
          expected =
            [interpolateYaml|
              data:
                #{schemaName}_authors_by_pk: null
            |]

      actual `shouldBe` expected

    it "Fails on missing tables" \testEnvironment -> do
      let schemaName :: Schema.SchemaName
          schemaName = Schema.getSchemaName testEnvironment

          actual :: IO Value
          actual =
            postGraphql
              testEnvironment
              [graphql|
                query {
                  #{schemaName}_unknown_by_pk(id: 5) {
                    id
                    name
                  }
                }
              |]

          expected :: Value
          expected =
            [interpolateYaml|
              errors:
              - extensions:
                  code: validation-failed
                  path: $.selectionSet.#{schemaName}_unknown_by_pk
                message: |-
                  field '#{schemaName}_unknown_by_pk' not found in type: 'query_root'
            |]

      actual `shouldBe` expected

    it "Fails on missing fields" \testEnvironment -> do
      let schemaName :: Schema.SchemaName
          schemaName = Schema.getSchemaName testEnvironment

          actual :: IO Value
          actual =
            postGraphql
              testEnvironment
              [graphql|
                query {
                  #{schemaName}_authors_by_pk(id: 5) {
                    unknown
                  }
                }
              |]

          expected :: Value
          expected =
            [interpolateYaml|
              errors:
              - extensions:
                  code: validation-failed
                  path: $.selectionSet.#{schemaName}_authors_by_pk.selectionSet.unknown
                message: |-
                  field 'unknown' not found in type: '#{schemaName}_authors'
            |]

      actual `shouldBe` expected

    it "Fails on missing primary key value" \testEnvironment -> do
      let schemaName :: Schema.SchemaName
          schemaName = Schema.getSchemaName testEnvironment

          actual :: IO Value
          actual =
            postGraphql
              testEnvironment
              [graphql|
                query {
                  #{schemaName}_authors_by_pk {
                    id
                  }
                }
              |]

          expected :: Value
          expected =
            [interpolateYaml|
              errors:
              - extensions:
                  code: validation-failed
                  path: $.selectionSet.#{schemaName}_authors_by_pk.args.id
                message: |-
                  missing required field 'id'
            |]

      actual `shouldBe` expected

    it "Fails on empty query" \testEnvironment -> do
      let schemaName :: Schema.SchemaName
          schemaName = Schema.getSchemaName testEnvironment

          actual :: IO Value
          actual =
            postGraphql
              testEnvironment
              [graphql|
                query {
                  #{schemaName}_authors_by_pk {
                  }
                }
              |]

          expected :: Value
          expected =
            [interpolateYaml|
              errors:
              - extensions:
                  code: validation-failed
                  path: $.query
                message: |-
                  not a valid graphql query
            |]

      actual `shouldBe` expected
