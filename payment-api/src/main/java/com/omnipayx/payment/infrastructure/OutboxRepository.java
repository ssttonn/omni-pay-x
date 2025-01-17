package com.omnipayx.payment.infrastructure;

import com.omnipayx.payment.domain.OutboxEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface OutboxRepository extends JpaRepository<OutboxEntity, UUID> {
    List<OutboxEntity> findByIsSentFalseOrderByCreatedAtAsc();
}
