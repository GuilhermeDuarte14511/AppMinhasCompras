$ErrorActionPreference = 'Stop'

$projectId = if ($env:GCLOUD_PROJECT) {
  $env:GCLOUD_PROJECT
} else {
  'minhascompras-3abbe'
}
$firestoreHost = if ($env:FIRESTORE_EMULATOR_HOST) {
  $env:FIRESTORE_EMULATOR_HOST
} else {
  '127.0.0.1:8080'
}
$authHost = if ($env:FIREBASE_AUTH_EMULATOR_HOST) {
  $env:FIREBASE_AUTH_EMULATOR_HOST
} else {
  '127.0.0.1:9099'
}
$databaseName = "projects/$projectId/databases/(default)"
$documentsUrl = "http://$firestoreHost/v1/$databaseName/documents"

function Invoke-JsonRequest {
  param(
    [Parameter(Mandatory = $true)][string] $Method,
    [Parameter(Mandatory = $true)][string] $Uri,
    [object] $Body,
    [string] $Token
  )

  $headers = @{}
  if ($Token) {
    $headers.Authorization = "Bearer $Token"
  }
  $parameters = @{
    Method = $Method
    Uri = $Uri
    Headers = $headers
    SkipHttpErrorCheck = $true
  }
  if ($null -ne $Body) {
    $parameters.ContentType = 'application/json'
    $parameters.Body = $Body | ConvertTo-Json -Depth 30 -Compress
    $script:lastRequestBody = $parameters.Body
  } else {
    $script:lastRequestBody = $null
  }
  return Invoke-WebRequest @parameters
}

function Assert-Status {
  param(
    [Parameter(Mandatory = $true)] $Response,
    [Parameter(Mandatory = $true)][int[]] $Expected,
    [Parameter(Mandatory = $true)][string] $Case
  )

  $status = [int]$Response.StatusCode
  if ($status -notin $Expected) {
    throw "$Case retornou HTTP $status. Corpo: $($Response.Content). Requisição: $script:lastRequestBody"
  }
  Write-Output "PASS [$status] $Case"
}

function New-TestUser {
  param([Parameter(Mandatory = $true)][string] $Alias)

  $response = Invoke-JsonRequest `
    -Method POST `
    -Uri "http://$authHost/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key" `
    -Body @{
      email = "$Alias-$(New-Guid)@example.test"
      password = 'Emulator-only-password-123!'
      returnSecureToken = $true
    }
  Assert-Status -Response $response -Expected 200 -Case "criar usuário $Alias"
  $payload = $response.Content | ConvertFrom-Json
  return @{
    uid = $payload.localId
    token = $payload.idToken
  }
}

function New-StringValue {
  param([Parameter(Mandatory = $true)][string] $Value)
  return @{ stringValue = $Value }
}

function New-MemberArray {
  param([Parameter(Mandatory = $true)][string[]] $Uids)
  return @{
    arrayValue = @{
      values = @($Uids | ForEach-Object { New-StringValue -Value $_ })
    }
  }
}

function New-ListFields {
  param(
    [Parameter(Mandatory = $true)][string] $ListId,
    [Parameter(Mandatory = $true)][string] $OwnerUid,
    [Parameter(Mandatory = $true)][string[]] $MemberUids,
    [Parameter(Mandatory = $true)][string] $InviteCode,
    [string] $CreatedAt
  )

  $fields = @{
    id = New-StringValue -Value $ListId
    name = New-StringValue -Value 'Lista protegida'
    ownerUid = New-StringValue -Value $OwnerUid
    memberUids = New-MemberArray -Uids $MemberUids
    inviteCode = New-StringValue -Value $InviteCode
  }
  if ($CreatedAt) {
    $fields.createdAt = @{ timestampValue = $CreatedAt }
  }
  return $fields
}

function New-ListWrite {
  param(
    [Parameter(Mandatory = $true)][string] $ListId,
    [Parameter(Mandatory = $true)] $Fields,
    [bool] $IsCreate = $false
  )

  $transforms = @(
    @{ fieldPath = 'updatedAt'; setToServerValue = 'REQUEST_TIME' }
  )
  if ($IsCreate) {
    $transforms += @{
      fieldPath = 'createdAt'
      setToServerValue = 'REQUEST_TIME'
    }
  }
  return @{
    update = @{
      name = "$databaseName/documents/shared_lists/$ListId"
      fields = $Fields
    }
    updateTransforms = $transforms
  }
}

function New-ClaimWrite {
  param(
    [Parameter(Mandatory = $true)][string] $Code,
    [Parameter(Mandatory = $true)][string] $Uid,
    [Parameter(Mandatory = $true)][string] $ListId
  )

  return @{
    update = @{
      name = "$databaseName/documents/invite_claims/$($Code)_$Uid"
      fields = @{
        code = New-StringValue -Value $Code
        uid = New-StringValue -Value $Uid
        listId = New-StringValue -Value $ListId
      }
    }
    updateTransforms = @(
      @{ fieldPath = 'createdAt'; setToServerValue = 'REQUEST_TIME' }
    )
  }
}

function Invoke-Commit {
  param(
    [Parameter(Mandatory = $true)] $Writes,
    [Parameter(Mandatory = $true)][string] $Token
  )

  return Invoke-JsonRequest `
    -Method POST `
    -Uri "$documentsUrl`:commit" `
    -Body @{ writes = @($Writes) } `
    -Token $Token
}

$owner = New-TestUser -Alias owner
$member = New-TestUser -Alias member
$third = New-TestUser -Alias third
$listId = "security-list-$(New-Guid)"
$inviteCode = 'ABCD2345'

$createList = New-ListWrite `
  -ListId $listId `
  -Fields (New-ListFields `
    -ListId $listId `
    -OwnerUid $owner.uid `
    -MemberUids @($owner.uid) `
    -InviteCode $inviteCode) `
  -IsCreate $true
$response = Invoke-Commit -Writes @($createList) -Token $owner.token
Assert-Status -Response $response -Expected 200 -Case 'dono cria lista só para si'

$invalidListId = "invalid-members-$(New-Guid)"
$invalidCreate = New-ListWrite `
  -ListId $invalidListId `
  -Fields (New-ListFields `
    -ListId $invalidListId `
    -OwnerUid $owner.uid `
    -MemberUids @($owner.uid, $third.uid) `
    -InviteCode $inviteCode) `
  -IsCreate $true
$response = Invoke-Commit -Writes @($invalidCreate) -Token $owner.token
Assert-Status -Response $response -Expected 403 -Case 'lista não nasce com terceiros'

$createInvite = @{
  update = @{
    name = "$databaseName/documents/list_invites/$inviteCode"
    fields = @{
      code = New-StringValue -Value $inviteCode
      listId = New-StringValue -Value $listId
      ownerUid = New-StringValue -Value $owner.uid
      active = @{ booleanValue = $true }
    }
  }
  updateTransforms = @(
    @{ fieldPath = 'createdAt'; setToServerValue = 'REQUEST_TIME' }
    @{ fieldPath = 'updatedAt'; setToServerValue = 'REQUEST_TIME' }
  )
}
$response = Invoke-Commit -Writes @($createInvite) -Token $owner.token
Assert-Status -Response $response -Expected 200 -Case 'dono cria convite ativo'

$response = Invoke-JsonRequest `
  -Method GET `
  -Uri "$documentsUrl/shared_lists/$listId" `
  -Token $owner.token
Assert-Status -Response $response -Expected 200 -Case 'dono lê a lista'
$listDocument = $response.Content | ConvertFrom-Json
$createdAt = ([DateTime]$listDocument.fields.createdAt.timestampValue).
  ToUniversalTime().
  ToString('o')

$response = Invoke-JsonRequest `
  -Method GET `
  -Uri "$documentsUrl/shared_lists/$listId" `
  -Token $third.token
Assert-Status -Response $response -Expected 403 -Case 'não membro não lê a lista'

$response = Invoke-JsonRequest `
  -Method POST `
  -Uri "$documentsUrl`:runQuery" `
  -Body @{ structuredQuery = @{ from = @(@{ collectionId = 'shared_lists' }) } } `
  -Token $third.token
Assert-Status -Response $response -Expected 403 -Case 'consulta global é bloqueada'

$response = Invoke-JsonRequest `
  -Method POST `
  -Uri "$documentsUrl`:runQuery" `
  -Body @{
    structuredQuery = @{
      from = @(@{ collectionId = 'shared_lists' })
      where = @{
        fieldFilter = @{
          field = @{ fieldPath = 'ownerUid' }
          op = 'EQUAL'
          value = New-StringValue -Value $owner.uid
        }
      }
    }
  } `
  -Token $owner.token
Assert-Status -Response $response -Expected 200 -Case 'dono consulta apenas as próprias listas'

$response = Invoke-JsonRequest `
  -Method GET `
  -Uri "$documentsUrl/list_invites/$inviteCode" `
  -Token $member.token
Assert-Status -Response $response -Expected 200 -Case 'código exato pode ser consultado'

$response = Invoke-JsonRequest `
  -Method POST `
  -Uri "$documentsUrl`:runQuery" `
  -Body @{ structuredQuery = @{ from = @(@{ collectionId = 'list_invites' }) } } `
  -Token $member.token
Assert-Status -Response $response -Expected 403 -Case 'convites não podem ser enumerados'

$memberListFields = New-ListFields `
  -ListId $listId `
  -OwnerUid $owner.uid `
  -MemberUids @($owner.uid, $member.uid) `
  -InviteCode $inviteCode `
  -CreatedAt $createdAt
$memberListWrite = New-ListWrite -ListId $listId -Fields $memberListFields
$response = Invoke-Commit -Writes @($memberListWrite) -Token $member.token
Assert-Status -Response $response -Expected 403 -Case 'entrada sem claim é bloqueada'

$invalidClaim = New-ClaimWrite `
  -Code 'ZZZZ9999' `
  -Uid $member.uid `
  -ListId $listId
$response = Invoke-Commit -Writes @($invalidClaim) -Token $member.token
Assert-Status -Response $response -Expected 403 -Case 'claim sem convite ativo é bloqueado'

$validClaim = New-ClaimWrite `
  -Code $inviteCode `
  -Uid $member.uid `
  -ListId $listId
$maliciousListFields = New-ListFields `
  -ListId $listId `
  -OwnerUid $owner.uid `
  -MemberUids @($owner.uid, $member.uid, $third.uid) `
  -InviteCode $inviteCode `
  -CreatedAt $createdAt
$maliciousListWrite = New-ListWrite `
  -ListId $listId `
  -Fields $maliciousListFields
$response = Invoke-Commit `
  -Writes @($validClaim, $maliciousListWrite) `
  -Token $member.token
Assert-Status -Response $response -Expected 403 -Case 'claim não permite adicionar terceiro'

$response = Invoke-Commit `
  -Writes @($validClaim, $memberListWrite) `
  -Token $member.token
Assert-Status -Response $response -Expected 200 -Case 'claim e entrada do próprio UID são atômicos'

$response = Invoke-JsonRequest `
  -Method GET `
  -Uri "$documentsUrl/shared_lists/$listId" `
  -Token $member.token
Assert-Status -Response $response -Expected 200 -Case 'novo membro lê a lista'

$response = Invoke-JsonRequest `
  -Method POST `
  -Uri "$documentsUrl`:runQuery" `
  -Body @{
    structuredQuery = @{
      from = @(@{ collectionId = 'shared_lists' })
      where = @{
        fieldFilter = @{
          field = @{ fieldPath = 'memberUids' }
          op = 'ARRAY_CONTAINS'
          value = New-StringValue -Value $member.uid
        }
      }
    }
  } `
  -Token $member.token
Assert-Status -Response $response -Expected 200 -Case 'membro consulta listas associadas'

$response = Invoke-JsonRequest `
  -Method POST `
  -Uri "$documentsUrl`:runQuery" `
  -Body @{
    structuredQuery = @{
      from = @(@{ collectionId = 'shared_lists' })
      where = @{
        fieldFilter = @{
          field = @{ fieldPath = 'memberUids' }
          op = 'ARRAY_CONTAINS'
          value = New-StringValue -Value $owner.uid
        }
      }
    }
  } `
  -Token $member.token
Assert-Status -Response $response -Expected 403 -Case 'membro não consulta associação de outro UID'

$ownerAddsThird = New-ListWrite `
  -ListId $listId `
  -Fields $maliciousListFields
$response = Invoke-Commit -Writes @($ownerAddsThird) -Token $owner.token
Assert-Status -Response $response -Expected 403 -Case 'dono não adiciona membro fora do convite'

$thirdClaim = New-ClaimWrite `
  -Code $inviteCode `
  -Uid $third.uid `
  -ListId $listId
$response = Invoke-Commit -Writes @($thirdClaim) -Token $third.token
Assert-Status -Response $response -Expected 200 -Case 'claim web pode ser criado antes da entrada'

$response = Invoke-Commit -Writes @($maliciousListWrite) -Token $third.token
Assert-Status -Response $response -Expected 200 -Case 'fluxo web adiciona somente o próprio UID'

$response = Invoke-JsonRequest `
  -Method DELETE `
  -Uri "$documentsUrl/invite_claims/$($inviteCode)_$($third.uid)" `
  -Token $third.token
Assert-Status -Response $response -Expected 200 -Case 'fluxo web limpa o claim'

$response = Invoke-JsonRequest `
  -Method DELETE `
  -Uri "$documentsUrl/invite_claims/$($inviteCode)_$($member.uid)" `
  -Token $member.token
Assert-Status -Response $response -Expected 200 -Case 'solicitante remove o próprio claim'

Write-Output 'Matriz crítica de listas compartilhadas validada no Emulator.'
