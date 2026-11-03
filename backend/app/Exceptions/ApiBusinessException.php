<?php

namespace App\Exceptions;

use DomainException;

class ApiBusinessException extends DomainException
{
    public function __construct(
        public readonly string $errorCode,
        string $message,
        public readonly int $httpStatus = 422,
        public readonly array $extraPayload = []
    ) {
        parent::__construct($message, $httpStatus);
    }
}
